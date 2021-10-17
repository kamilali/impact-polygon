// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";
import "@opengsn/contracts/src/forwarder/Forwarder.sol";

import './interfaces/ERC20Permit.sol';

contract ImpactPayment is BaseRelayRecipient {
    using SafeMath for uint256;
    
    string public override versionRecipient = "2.0.0";

    address public owner;
    uint public total_transactions = 0;

    uint256 test_value = 0;

    mapping(address => uint) public deposits; // total deposited funds
    mapping(address => bool) public tokens_allowed;

    event Deposit(address indexed sender, uint amount);
    event Withdraw(address indexed recipient, uint amount);
    
    constructor(address[] memory token_addresses, address forwarder) {
        owner = msg.sender;
        for(uint256 i = 0; i < token_addresses.length; i++) {
            tokens_allowed[token_addresses[i]] = true;
        }
        trustedForwarder = forwarder;
    }

    function testContractFunction(uint256 testValue) public {
        test_value = testValue;
    }

    function testGetContractFunction() public view returns (uint256) {
        return test_value;
    }

    function depositFunds(address tokenAddress, uint256 amount) public {
        require(tokens_allowed[tokenAddress], "We do not accept deposits of this ERC20 token");
        require(ERC20(tokenAddress).balanceOf(_msgSender()) >= amount, 
                "You do not have sufficient funds to make this purchase");
        ERC20(tokenAddress).transferFrom(_msgSender(), address(this), amount);
        emit Deposit(_msgSender(), amount);
        deposits[_msgSender()] += amount;
        total_transactions++;
    }

    function permitContractWithdrawals(address tokenAddress, address holder, address spender, 
                                       uint256 nonce, uint256 expiry, bool allowed, 
                                       uint8 v, bytes32 r, bytes32 s) public {
        ERC20Permit(tokenAddress).permit(holder, spender, nonce, expiry, allowed, v, r, s);
    }

    // function acceptRelayedCall(
    //     address,
    //     address from,
    //     bytes calldata encodedFunction,
    //     uint256 transactionFee,
    //     uint256 gasPrice,
    //     uint256,
    //     uint256,
    //     bytes calldata,
    //     uint256 maxPossibleCharge
    // ) external view override returns (uint256, bytes memory) {
    //     // decode function selector
    //     // verify that the function call is okay to approve
    //     if (abi.decode(encodedFunction[:4], (bytes4)) == bytes4(keccak256("depositFunds(address,uint256)"))) {
    //         // decode function parameters to get token that is being used for payment
    //         (address tokenAddress) = abi.decode(encodedFunction[4:], (address));
    //         if (tokens_allowed[tokenAddress]) {
    //             // verify that we have access to charge the user the gas fee (from address)
    //             // verify they have enough funds in token specified by tokenAddress
    //             if ((ERC20(tokenAddress).allowance(from, address(this)) >= maxPossibleCharge)
    //                 && (ERC20(tokenAddress).balanceOf(from) >= maxPossibleCharge)) {
    //                 return _approveRelayedCall(
    //                     abi.encode(from, tokenAddress, maxPossibleCharge, transactionFee, gasPrice));
    //             }
    //         }
    //     }
    //     return _rejectRelayedCall(0);
    // }

    // function _preRelayedCall(bytes memory context) internal override returns (bytes32) {
    //     // charge the user the max possible gas fee, this will be refunded later if in excess
    //     (address payer, address tokenAddress, uint256 maxPossibleCharge) = 
    //         abi.decode(context, (address, address, uint256));
    //     ERC20(tokenAddress).transferFrom(payer, address(this), maxPossibleCharge);
    //     return bytes32("");
    // }

    // function _postRelayedCall(bytes memory context, bool, uint256 actualCharge, bytes32) internal override {
    //     // resolve any gas fee discrepancies and refund the user using the relay hub contract call
    //     (address payer, address tokenAddress, uint256 maxPossibleCharge, uint256 transactionFee, uint256 gasPrice) = 
    //         abi.decode(context, (address, address, uint256, uint256, uint256));
    //     uint256 postGasOverestimation = _computeCharge(_POST_RELAYED_CALL_MAX_GAS.sub(10000), gasPrice, transactionFee); // not sure how to get this yet
    //     uint256 refundPayment = maxPossibleCharge.sub(actualCharge.sub(postGasOverestimation));
    //     ERC20(tokenAddress).transfer(payer, refundPayment);
    //     depositProceedsToHub(actualCharge.sub(postGasOverestimation));
    // }

    // function depositProceedsToHub(uint256 amount) public {
    //     IRelayHub(getHubAddr()).depositFor{value:amount}(address(this));
    // }

}
