// SPDX-License-Identifier:MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@opengsn/contracts/src/forwarder/IForwarder.sol";
import "@opengsn/contracts/src/interfaces/IRelayHub.sol";
import "@opengsn/contracts/src/BasePaymaster.sol";

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';

import "./interfaces/ERC20Permit.sol";

/**
 * A Token-based paymaster.
 * - each request is paid for by the caller.
 * - acceptRelayedCall - verify the caller can pay for the request in tokens.
 * - preRelayedCall - pre-pay the maximum possible price for the tx
 * - postRelayedCall - refund the caller for the unused gas
 */
contract ImpactPaymaster is BasePaymaster {
    using SafeMath for uint256;

    function versionPaymaster() external override virtual view returns (string memory) {
        return "2.2.0+opengsn.token.ipaymaster";
    }

    address[] public tokens;
    mapping (address=>bool) private supportedTokens;

    ISwapRouter public immutable swapRouter;
    address public WETH9;
    // pool fee set to 0.3%.
    uint24 public constant poolFee = 3000;
    uint32 private constant tickWindow = 100;

    uint public gasUsedByPost;

    constructor(address[] memory _tokens, address wETH9Address, address swapRouterAddress, address forwarder, address relayHub) {
        swapRouter = ISwapRouter(swapRouterAddress);
        WETH9 = wETH9Address;
        for (uint256 i = 0; i < _tokens.length; i++){
            supportedTokens[_tokens[i]] = true;
            tokens.push(_tokens[i]);
            // tokens[i].approve(address(UniswapV2Router02), type(uint256).max);
            setTrustedForwarder(IForwarder(forwarder));
            setRelayHub(IRelayHub(relayHub));
        }
    }

    /**
     * set gas used by postRelayedCall, for proper gas calculation.
     * You can use TokenGasCalculator to calculate these values (they depend on actual code of postRelayedCall,
     * but also the gas usage of the token and of Uniswap)
     */
    function setPostGasUsage(uint _gasUsedByPost) external onlyOwner {
        gasUsedByPost = _gasUsedByPost;
    }

    // return the payer of this request.
    // for account-based target, this is the target account.
    function getPayer(GsnTypes.RelayRequest calldata relayRequest) public virtual view returns (address) {
        (this);
        return relayRequest.request.from;
    }

    event Received(uint eth);
    receive() external override payable {
        emit Received(msg.value);
    }

    function _getToken(bytes memory requestData) internal view returns (address tokenAddress) {
        //if no specific token specified, assume the first in the list.
        if (requestData.length==0) {
            return tokens[0];
        }
        (tokenAddress) = abi.decode(requestData, (address));
        require(supportedTokens[tokenAddress], "not a supported token");
    }

    function _calculatePreCharge(
        address tokenAddress,
        GsnTypes.RelayRequest calldata relayRequest,
        uint256 maxPossibleGas)
    internal
    view
    returns (address payer, uint256 tokenPreCharge) {
        (tokenAddress);
        payer = this.getPayer(relayRequest);
        uint ethMaxCharge = relayHub.calculateCharge(maxPossibleGas, relayRequest.relayData);
        ethMaxCharge += relayRequest.request.value;
        // TODO: get amount of tokens that equals the eth max charge
        tokenPreCharge = getQuoteFromOracle(ethMaxCharge, WETH9, tokenAddress);
        // tokenPreCharge = uniswap.getTokenToEthOutputPrice(ethMaxCharge);
    }

    function preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
    external
    override
    virtual
    relayHubOnly
    returns (bytes memory context, bool revertOnRecipientRevert) {
        (relayRequest, signature, approvalData, maxPossibleGas);
        address tokenAddress = _getToken(relayRequest.request.data);
        (address payer, uint256 tokenPrecharge) = _calculatePreCharge(tokenAddress, relayRequest, maxPossibleGas);
        ERC20Permit(tokenAddress).transferFrom(payer, address(this), tokenPrecharge);
        return (abi.encode(payer, tokenPrecharge, tokenAddress), false);
    }

    function postRelayedCall(
        bytes calldata context,
        bool,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    )
    external
    override
    virtual
    relayHubOnly {
        (address payer, uint256 tokenPrecharge, address tokenAddress) = abi.decode(context, (address, uint256, address));
        _postRelayedCallInternal(payer, tokenPrecharge, 0, gasUseWithoutPost, relayData, tokenAddress);
    }

    function _postRelayedCallInternal(
        address payer,
        uint256 tokenPrecharge,
        uint256 valueRequested,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData,
        address tokenAddress
    ) internal {
        uint256 ethActualCharge = relayHub.calculateCharge(gasUseWithoutPost.add(gasUsedByPost), relayData);
        // TODO: get amount of tokens that equals the eth price for refund calculation
        uint256 tokenActualCharge = getQuoteFromOracle(valueRequested.add(ethActualCharge), WETH9, tokenAddress);
        // uint256 tokenActualCharge = uniswap.getTokenToEthOutputPrice(valueRequested.add(ethActualCharge));
        uint256 tokenRefund = tokenPrecharge.sub(tokenActualCharge);
        _refundPayer(payer, tokenAddress, tokenRefund);
        _depositProceedsToHub(ethActualCharge, tokenAddress);
        emit TokensCharged(gasUseWithoutPost, gasUsedByPost, ethActualCharge, tokenActualCharge);
    }

    function _refundPayer(
        address payer,
        address tokenAddress,
        uint256 tokenRefund
    ) private {
        require(ERC20Permit(tokenAddress).transfer(payer, tokenRefund), "failed refund");
    }

    function _depositProceedsToHub(uint256 ethActualCharge, address tokenAddress) private {
        //solhint-disable-next-line
        swapExactETHOutputSingle(tokenAddress, ethActualCharge, type(uint256).max);
        // uniswap.tokenToEthSwapOutput(ethActualCharge, type(uint256).max, block.timestamp+60*15);
        relayHub.depositFor{value:ethActualCharge}(address(this));
    }
    
    event TokensCharged(uint gasUseWithoutPost, uint gasJustPost, uint ethActualCharge, uint tokenActualCharge);

    /// UNISWAP HELPER METHODS
    
    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (address) {
        return PoolAddress.computeAddress(IPeripheryImmutableState(address(swapRouter)).factory(),
                                          PoolAddress.getPoolKey(tokenA, tokenB, fee));
    }

    function getQuoteFromOracle(uint256 baseAmount, address baseToken, address quoteToken) private view returns (uint256 quoteAmount) {
        address poolAddress = getPool(baseToken, quoteToken, poolFee);
        int24 tick = OracleLibrary.consult(poolAddress, tickWindow);
        quoteAmount = OracleLibrary.getQuoteAtTick(tick, uint128(baseAmount), baseToken, quoteToken);
    }

    /// @notice swapExactInputSingle swaps a fixed amount of input token for a maximum possible amount of WETH9
    /// using the Token/WETH9 0.3% pool by calling `exactInputSingle` in the swap router.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
    /// @param amountIn The exact amount of the token that will be swapped for WETH9.
    /// @return amountOut The amount of WETH9 received.
    function swapExactInputToETHSingle(address tokenAddress, uint256 amountIn) private returns (uint256 amountOut) {
        // Approve the router to spend DAI.
        TransferHelper.safeApprove(tokenAddress, address(swapRouter), amountIn);

        // Naively set amountOutMinimum to 0.
        // TODO: In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenAddress,
                tokenOut: WETH9,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: getQuoteFromOracle(amountIn, tokenAddress, WETH9),
                sqrtPriceLimitX96: 0
            });

        // Execute the swap
        amountOut = swapRouter.exactInputSingle(params);
    }

    /// @notice swapExactOutputSingle swaps a minimum possible amount of token for a fixed amount of WETH.
    /// @dev The calling address must approve this contract to spend its token for this function to succeed. 
    /// As the amount of input DAI is variable, the calling address will need to approve for a slightly higher amount, 
    /// anticipating some variance.
    /// @param amountOut The exact amount of WETH9 to receive from the swap.
    /// @param amountInMaximum The amount of the token we are willing to spend to receive the specified amount of WETH9.
    /// @return amountIn The amount of the token actually spent in the swap.
    function swapExactETHOutputSingle(address tokenAddress, 
                                   uint256 amountOut, 
                                   uint256 amountInMaximum) private returns (uint256 amountIn) {

        // Approve the router to spend the specifed `amountInMaximum` of DAI.
        // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
        TransferHelper.safeApprove(tokenAddress, address(swapRouter), amountInMaximum);

        ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: tokenAddress,
                tokenOut: WETH9,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountIn = swapRouter.exactOutputSingle(params);

        // For exact output swaps, the amountInMaximum may not have all been spent.
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must approve the swapRouter to spend 0.
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(tokenAddress, address(swapRouter), 0);
        }
    }

}