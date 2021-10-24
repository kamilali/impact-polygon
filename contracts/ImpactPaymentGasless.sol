// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";
import "@opengsn/contracts/src/forwarder/Forwarder.sol";

import './interfaces/ERC20Permit.sol';

contract ImpactPaymentGasless is BaseRelayRecipient {
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
}
