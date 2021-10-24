// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import './interfaces/ERC20Permit.sol';


contract ImpactPayment is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    
    uint public total_transactions = 0;
    Counters.Counter private _campaignIds;
    
    struct ImpactCampaign {
        uint256 id;
        address campaignOwner;
        string ownerName;
    }

    mapping(address => bool) public tokens_allowed;
    mapping(address => uint256) public deposits; // total deposited funds for a user

    mapping(uint256 => mapping(address => uint256)) public campaignDeposits; // total deposited funds for a user
    mapping(uint256 => uint256) public campaignFunds; // total funds of a campaign
    mapping(uint256 => ImpactCampaign) public idToImpactCampaign; // impact campaigns that are launched
    mapping(address => uint256[]) public userToImpactCampaignIds;

    event CampaignCreated(uint256 id, address campaignOwner, string ownerName);
    event Deposit(address indexed sender, uint256 amount, uint256 campaignId);
    event Withdraw(address indexed recipient, uint256 amount, uint256 campaignId);
    
    constructor(address[] memory token_addresses) {
        for(uint256 i = 0; i < token_addresses.length; i++) {
            tokens_allowed[token_addresses[i]] = true;
        }
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

    function getCampaigns() public view returns (ImpactCampaign[] memory) {
        uint256 campaignCount = _campaignIds.current();
        ImpactCampaign[] memory impactCampaigns = new ImpactCampaign[](campaignCount);
        for(uint256 i = 0; i < campaignCount; i++) {
            impactCampaigns[i] = idToImpactCampaign[i+1];
        }
        return impactCampaigns;
    }
    
    function createCampaign(address campaignOwner, string memory ownerName) public onlyOwner {
        _campaignIds.increment();
        uint256 campaignId = _campaignIds.current();
        idToImpactCampaign[campaignId] = ImpactCampaign(
            campaignId,
            campaignOwner,
            ownerName
        );
        emit CampaignCreated(campaignId, campaignOwner, ownerName);
    }

    function depositFunds(address tokenAddress, uint256 amount, uint256 campaignId) public {
        require(tokens_allowed[tokenAddress], "We do not accept deposits of this ERC20 token");
        require(ERC20(tokenAddress).balanceOf(msg.sender) >= amount, 
                "You do not have sufficient funds to make this purchase");
        ERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount, campaignId);
        deposits[msg.sender] += amount;
        campaignDeposits[campaignId][msg.sender] += amount;
        campaignFunds[campaignId] += amount;
        total_transactions++;
    }
    
    function allowTokenDeposits(address tokenAddress) public onlyOwner {
        tokens_allowed[tokenAddress] = true;
    }
}
