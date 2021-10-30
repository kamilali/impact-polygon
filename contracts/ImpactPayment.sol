// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';

import './interfaces/ERC20Permit.sol';


contract ImpactPayment is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    
    uint public total_transactions = 0;
    Counters.Counter private _campaignIds;
    Counters.Counter private _campaignsCompleted;
    
    struct ImpactCampaign {
        uint256 id;
        address campaignOwner;
        string campaignName;
        string ownerName;
        bool complete;
    }

    struct Donation {
        address donor;
        uint256 donationAmount;
    }

    mapping(address => bool) public tokens_allowed;
    address private _baseTokenAddress;
    ISwapRouter private immutable swapRouter;
    uint24 private constant poolFee = 3000;
    uint32 private constant tickWindow = 100;
    
    mapping(address => uint256) public deposits; // total deposited funds for a user

    mapping(uint256 => mapping(address => uint256)) public campaignDeposits; // total deposited funds for a user
    mapping(uint256 => uint256) public campaignFunds; // total funds of a campaign
    mapping(uint256 => ImpactCampaign) public idToImpactCampaign; // impact campaigns that are launched
    mapping(address => uint256[]) public userToImpactCampaignIds;
    mapping(uint256 => address[]) public impactCampaignIdsToUsers;

    event CampaignCreated(uint256 indexed id, address campaignOwner, string campaignName, string ownerName);
    event Deposit(address indexed sender, uint256 amount, uint256 campaignId);
    event Withdraw(address indexed recipient, uint256 amount, uint256 campaignId);
    
    constructor(address[] memory tokenAddresses, address baseTokenAddress, address swapRouterAddress) {
        for(uint256 i = 0; i < tokenAddresses.length; i++) {
            tokens_allowed[tokenAddresses[i]] = true;
        }
        _baseTokenAddress = baseTokenAddress;
        swapRouter = ISwapRouter(swapRouterAddress);
    }
    
    function getCampaignFunds(uint256 campaignId) public view returns (uint256) {
        return campaignFunds[campaignId];
    }

    function getUserTotalDeposits() public view returns (uint256) {
        return deposits[msg.sender];
    }

    function getUserCampaignDeposits(uint256 campaignId) public view returns (uint256) {
        return campaignDeposits[campaignId][msg.sender];
    }

    function getUserDonatedCampaigns() public view returns (ImpactCampaign[] memory) {
        uint256[] memory userDonatedCampaignIds = userToImpactCampaignIds[msg.sender];
        ImpactCampaign[] memory userDonatedCampaigns = new ImpactCampaign[](userDonatedCampaignIds.length);
        for(uint256 i = 0; i < userDonatedCampaignIds.length; i++) {
            userDonatedCampaigns[i] = idToImpactCampaign[userDonatedCampaignIds[i]];
        }
        return userDonatedCampaigns;
    }

    function getUserDonationsToCampaign(uint256 campaignId) public view returns (Donation[] memory) {
        address[] memory usersThatDonatedToCampaign = impactCampaignIdsToUsers[campaignId];
        Donation[] memory userDonations = new Donation[](usersThatDonatedToCampaign.length);
        for (uint256 i = 0; i < usersThatDonatedToCampaign.length; i++) {
            userDonations[i] = Donation(
                usersThatDonatedToCampaign[i],
                campaignDeposits[campaignId][usersThatDonatedToCampaign[i]]
            );
        }
        return userDonations;
    }

    function getCampaigns() public view returns (ImpactCampaign[] memory) {
        uint256 campaignCount = _campaignIds.current();
        ImpactCampaign[] memory impactCampaigns = new ImpactCampaign[](campaignCount);
        for(uint256 i = 0; i < campaignCount; i++) {
            impactCampaigns[i] = idToImpactCampaign[i+1];
        }
        return impactCampaigns;
    }
    
    function getActiveCampaigns() public view returns (ImpactCampaign[] memory) {
        uint256 campaignCount = _campaignIds.current() - _campaignsCompleted.current();
        ImpactCampaign[] memory impactCampaigns = new ImpactCampaign[](campaignCount);
        for(uint256 i = 0; i < campaignCount; i++) {
            if (!idToImpactCampaign[i+1].complete) {
                impactCampaigns[i] = idToImpactCampaign[i+1];
            }
        }
        return impactCampaigns;
    }
    
    function getCompletedCampaigns() public view returns (ImpactCampaign[] memory) {
        uint256 campaignCount = _campaignsCompleted.current();
        ImpactCampaign[] memory impactCampaigns = new ImpactCampaign[](campaignCount);
        for(uint256 i = 0; i < campaignCount; i++) {
            if (idToImpactCampaign[i+1].complete) {
                impactCampaigns[i] = idToImpactCampaign[i+1];
            }
        }
        return impactCampaigns;
    }
    
    function createCampaign(address campaignOwner, string memory campaignName, string memory ownerName) public onlyOwner {
        _campaignIds.increment();
        uint256 campaignId = _campaignIds.current();
        idToImpactCampaign[campaignId] = ImpactCampaign(
            campaignId,
            campaignOwner,
            campaignName,
            ownerName,
            false
        );
        emit CampaignCreated(campaignId, campaignOwner, campaignName, ownerName);
    }

    function endCampaign(uint256 campaignId) public onlyOwner {
        require(campaignId < _campaignIds.current(), "Invalid campaign id");
        ImpactCampaign storage currCampaign = idToImpactCampaign[campaignId];
        currCampaign.complete = true;
        _campaignsCompleted.increment();
    }

    function withdrawFunds(uint256 campaignId, uint256 amount) public onlyOwner {
        require(ERC20(_baseTokenAddress).balanceOf(address(this)) >= amount,
                "There are not sufficient funds for this withdrawal");
        require(campaignFunds[campaignId] >= amount,
                "This campaign does not have sufficient funds for this withdrawal");
        address campaignOwner = idToImpactCampaign[campaignId].campaignOwner;
        ERC20(_baseTokenAddress).transfer(campaignOwner, amount);
        campaignFunds[campaignId] -= amount;
        emit Withdraw(campaignOwner, amount, campaignId);
    }

    function depositFunds(address tokenAddress, uint256 amount, uint256 campaignId) public {
        require(tokens_allowed[tokenAddress], "We do not accept deposits of this ERC20 token");
        require(ERC20(tokenAddress).balanceOf(msg.sender) >= amount, 
                "You do not have sufficient funds to make this purchase");
        ERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        // use Uniswap to transfer token if it is not the base token that this
        // contract stores
        if(tokenAddress != _baseTokenAddress) {
            // convert to base token using uniswap router
            // amount is exact in some allowed token deposit
            // that is not the base token accepted by the contract
            // need to convert to max baseTokens possible
            swapExactInputToBaseTokenSingle(tokenAddress, amount);
        }
        deposits[msg.sender] += amount;
        userToImpactCampaignIds[msg.sender].push(campaignId);
        impactCampaignIdsToUsers[campaignId].push(msg.sender);
        campaignDeposits[campaignId][msg.sender] += amount;
        campaignFunds[campaignId] += amount;
        total_transactions++;
        emit Deposit(msg.sender, amount, campaignId);
    }
    
    function allowTokenDeposits(address tokenAddress) public onlyOwner {
        tokens_allowed[tokenAddress] = true;
    }
    
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
    function swapExactInputToBaseTokenSingle(address tokenAddress, uint256 amountIn) private returns (uint256 amountOut) {
        // Approve the router to spend DAI.
        TransferHelper.safeApprove(tokenAddress, address(swapRouter), amountIn);

        // Naively set amountOutMinimum to 0.
        // TODO: In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenAddress,
                tokenOut: _baseTokenAddress,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: getQuoteFromOracle(amountIn, tokenAddress, _baseTokenAddress),
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
    function swapExactBaseTokenOutputSingle(address tokenAddress, 
                                   uint256 amountOut, 
                                   uint256 amountInMaximum) private returns (uint256 amountIn) {

        // Approve the router to spend the specifed `amountInMaximum` of DAI.
        // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
        TransferHelper.safeApprove(tokenAddress, address(swapRouter), amountInMaximum);

        ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: tokenAddress,
                tokenOut: _baseTokenAddress,
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
