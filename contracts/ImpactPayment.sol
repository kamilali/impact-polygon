// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ImpactPayment is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    
    Counters.Counter private _campaignIds;
    
    struct ImpactCampaign {
        uint256 id;
        address campaignOwner;
        string campaignName;
        string ownerName;
        bool complete;
    }

    mapping(uint256 => mapping(address => uint256)) public campaignDeposits; // total deposited funds for a user
    mapping(uint256 => uint256) public campaignFunds; // total funds of a campaign
    mapping(uint256 => ImpactCampaign) public idToImpactCampaign; // impact campaigns that are launched

    event CampaignCreated(uint256 indexed id, address campaignOwner, string campaignName, string ownerName);
    event Deposit(address indexed sender, uint256 amount, uint256 campaignId);
    event Withdraw(address indexed recipient, uint256 amount, uint256 campaignId);
    
    constructor() {}
    
    function getCampaignFunds(uint256 campaignId) public view returns (uint256) {
        return campaignFunds[campaignId];
    }

    function getUserCampaignDeposits(uint256 campaignId, address userAddress) public view returns (uint256) {
        return campaignDeposits[campaignId][userAddress];
    }

    function getCampaigns() public view returns (ImpactCampaign[] memory) {
        uint256 campaignCount = _campaignIds.current();
        ImpactCampaign[] memory impactCampaigns = new ImpactCampaign[](campaignCount);
        for(uint256 i = 0; i < campaignCount; i++) {
            impactCampaigns[i] = idToImpactCampaign[i+1];
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
    }
    
    function withdrawFundsETH(uint256 campaignId, uint256 amount) public onlyOwner {
        require(campaignFunds[campaignId] >= amount, 
                "This campaign does not have sufficient funds for this withdrawal");
        require(address(this).balance >= amount, 
                "This campaign does not have sufficient ETH for this withdrawal");
        address campaignOwner = idToImpactCampaign[campaignId].campaignOwner;
        payable(campaignOwner).transfer(amount);
        emit Withdraw(campaignOwner, amount, campaignId);
    }

    function depositFundsETH(uint256 campaignId) public payable {
        campaignDeposits[campaignId][msg.sender] += msg.value;
        campaignFunds[campaignId] += msg.value;
        emit Deposit(msg.sender, msg.value, campaignId);
    }
}