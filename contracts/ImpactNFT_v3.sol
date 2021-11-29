// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ImpactNFTv3 is ERC721Enumerable, Ownable, ERC721Burnable, ERC721Pausable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdTracker;

    struct CampaignNFT {
        string[] identifiers; // identifier for specific NFTs in the campaign
        mapping(string => uint256) requiredDonationAmounts; // Base donation mount required per mint
        mapping(string => uint256) maxElements; // The max number of elements in the collection
        mapping(string => uint256) maxByMints; // Max number of mints per transaction
        mapping(string => string) baseTokenURIs; // Base token URI of collection.. should be ipfs://{HASH}/
        mapping(string => string) hiddenTokenURIs; // Token URI of hidden object
        mapping(string => bool) isRevealed; // Determines if the token is revealed
    }
    
    address private marketplaceContract;
    address private withdrawAllAddress;
    mapping(address => bool) minters;
    mapping(uint256 => CampaignNFT) campaignNFTs;
    mapping(uint256 => Counters.Counter) tokenIdTrackers;

    event CreateImpactToken(uint256 indexed id);
    event CampaignCreated(uint256 id);
    
    constructor(address _withdrawAllAddress, address[] memory _minters, address _marketplaceContract) ERC721("ImpactNFT", "IMPACT") {
        // setBaseURI(baseURI);
        // setHiddenURI(__hiddenURI);
        setWithdrawAllAddress(_withdrawAllAddress);
        marketplaceContract = _marketplaceContract;
        for(uint256 i = 0; i < _minters.length; i++) {
            minters[_minters[i]] = true;
        }
    }

    modifier allowedMinters {
        require(_msgSender() == owner() || _msgSender() == marketplaceContract || minters[_msgSender()]);
        _;
    }

    function addCampaignNFTs(uint256 campaignId,
                             string[] memory identifiers, 
                             uint256[] memory requiredDonationAmounts,
                             uint256[] memory maxElements,
                             uint256[] memory maxByMints,
                             string[] memory baseTokenURIs,
                             string[] memory hiddenTokenURIs,
                             bool[] memory isRevealed) public onlyOwner {
        // TODO: FIX this
        campaignNFTs[campaignId].identifiers = identifiers;
        for(uint256 i = 0; i < identifiers.length; i++) {
            campaignNFTs[campaignId].requiredDonationAmounts[identifiers[i]] = requiredDonationAmounts[i];
            campaignNFTs[campaignId].maxElements[identifiers[i]] = maxElements[i];
            campaignNFTs[campaignId].maxByMints[identifiers[i]] = maxByMints[i];
            campaignNFTs[campaignId].baseTokenURIs[identifiers[i]] = baseTokenURIs[i];
            campaignNFTs[campaignId].hiddenTokenURIs[identifiers[i]] = hiddenTokenURIs[i];
            campaignNFTs[campaignId].isRevealed[identifiers[i]] = isRevealed[i];
        }
        emit CampaignCreated(campaignId);
    }

    function addMinter(address minter) public onlyOwner {
        minters[minter] = true;
    }

    function _totalSupply(uint256 campaignId) internal view returns (uint) {
        return tokenIdTrackers[campaignId].current();
    }

    function mint(uint256 campaignId, string memory identifier, address _to, uint256 _count) public payable allowedMinters {

        uint256 total = _totalSupply(campaignId);
        require(total + _count <= campaignNFTs[campaignId].maxElements[identifier], "Max limit");
        require(_count <= campaignNFTs[campaignId].maxByMints[identifier], "Exceeds number");
        require(msg.value >= price(campaignId, identifier, _count), "Value below price");

        for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(campaignId, identifier, _to);
        }
    }

    function _mintAnElement(uint256 campaignId, string memory identifier, address _to) private {
        uint id = _totalSupply(campaignId);
        require(id + 1 <= campaignNFTs[campaignId].maxElements[identifier], "Max limit has been reached");
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateImpactToken(id);
    }
    
    function mintAnElement(uint256 campaignId, string memory identifier, address _to) public payable allowedMinters {
        uint id = _totalSupply(campaignId);
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateImpactToken(id);
    }

    function price(uint256 campaignId, string memory identifier, uint256 _count) public pure returns (uint256) {
        return campaignNFTs[campaignId].requiredDonationAmounts[identifier].mul(_count);
    }

    function mintUnique(address _to, uint256 id) public payable onlyOwner {
        _safeMint(_to, id);
        emit CreateImpactToken(id);
    }

    function _baseURI(uint256 campaignId, string memory identifier) internal view virtual override returns (string memory) {
        return campaignNFTs[campaignId].baseTokenURIs[identifier];
    }

    function _hiddenURI(uint256 campaignId, string memory identifier) public view virtual returns (string memory) {
        return campaignNFTs[campaignId].hiddenTokenURIs[identifier];
    }

    function setBaseURI(uint256 campaignId, string memory identifier, string memory baseURI) public onlyOwner {
        campaignNFTs[campaignId].baseTokenURIs[identifier] = baseURI;
    }

    function setHiddenURI(uint256 campaignId, string memory identifier, string memory __hiddenURI) public onlyOwner {
        campaignNFTs[campaignId].hiddenTokenURIs[identifier] = __hiddenURI;
    }

    function setWithdrawAllAddress(address withdrwAddr) public onlyOwner {
        withdrawAllAddress = withdrwAddr;
    }

    function getHiddenURI(uint256 campaignId, string memory identifier) public view onlyOwner returns (string memory) {
        return campaignNFTs[campaignId].hiddenTokenURIs[identifier];
    }

    function reveal(uint256 campaignId, string memory identifier) public onlyOwner {
        campaignNFTs[campaignId].isRevealed[identifier] = true;
    }

    function hide(uint256 campaignId, string memory identifier) public onlyOwner {
        campaignNFTs[campaignId].isRevealed[identifier] = false;
    }

    function _isRevealed(uint256 campaignId, string memory identifier) public pure returns(bool) {
        return campaignNFTs[campaignId].isRevealed[identifier];
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function tokenURI(uint256 campaignId, string memory identifier, uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (!_isRevealed(campaignId, identifier)) {
            return _hiddenURI(campaignId, identifier);
        }

        return bytes(_baseURI()).length > 0
            ? string(abi.encodePacked(_baseURI(), tokenId.toString(), ".json"))
            : "";
    }

    function pause() public onlyOwner {
        require(!paused(), "Not unpaused");
        _unpause();
    }

    function unpause() public onlyOwner {
        require(paused(), "Not paused");
        _unpause();
    }

    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _withdraw(withdrawAllAddress, address(this).balance);
    }

    function _withdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
