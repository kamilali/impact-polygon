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

contract ImpactKAB_NFT is ERC721Enumerable, Ownable, ERC721Burnable, ERC721Pausable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter[3] private _tokenIdTrackers;

    uint256 public DONOR_MAX_ELEMENTS = 200; // The max number of elements in the collection
    uint256 public GM_MAX_ELEMENTS = 14;     // The max number of elements in the collection
    uint256 public WAGMI_MAX_ELEMENTS = 5;   // The max number of elements in the collection
    uint256 public DONOR_PRICE = 0.12 ether; // Base price per mint
    uint256 public GM_PRICE = 0.6 ether;     // Base price per mint
    uint256 public WAGMI_PRICE = 1 ether;    // Base price per mint
    string public baseTokenURI;                       // Base token URI of collection.. should be ipfs://{HASH}/
    string public hiddenURI;                          // Token URI of hidden object
    bool public isRevealed = false;                   // Determines if the token is revealed
    
    address private marketplaceContract;
    address private withdrawAllAddress;
    mapping(address => bool) minters;

    event CreateImpactToken(uint256 indexed id);
    
    constructor(string memory baseURI, string memory __hiddenURI, address _withdrawAllAddress, address[] memory _minters, address _marketplaceContract) ERC721("ImpactxKAB", "IMPACTKAB") {
        setBaseURI(baseURI);
        setHiddenURI(__hiddenURI);
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

    function addMinter(address minter) public onlyOwner {
        minters[minter] = true;
    }

    function _totalSupply(uint256 i) internal view returns (uint) {
        return _tokenIdTrackers[i].current();
    }

    function totalMinted(uint256 i) public view returns (uint256) {
        return _tokenIdTrackers[i].current();
    }
    
    function maxElements(uint256 i) public view returns (uint256) {
        require(i == 0 || i == 1 || i == 2);
        if (i == 0) return DONOR_MAX_ELEMENTS;
        else if (i == 1) return GM_MAX_ELEMENTS;
        return WAGMI_MAX_ELEMENTS;
    }

    function mint(address _to, uint256[] memory counts) public allowedMinters {
        require(counts.length == 3, "Improper counts length");
        for (uint256 i = 0; i < counts.length; i++) {
            if (counts[i] > 0) {
                uint256 offset = 0;
                uint256 total = _totalSupply(i);
                uint256 maxLimit = 0;
                // select which token to mint
                if (i == 0) { 
                    maxLimit = DONOR_MAX_ELEMENTS; 
                    offset = 0;
                }
                else if (i == 1) {
                    maxLimit = GM_MAX_ELEMENTS;
                    offset = DONOR_MAX_ELEMENTS;
                }
                else {
                    maxLimit = WAGMI_MAX_ELEMENTS;
                    offset = DONOR_MAX_ELEMENTS + GM_MAX_ELEMENTS;
                }
                require(total + counts[i] <= maxLimit, "Max limit reached");
                for (uint256 j = 0; j < counts[i]; j++) {
                    _mintAnElement(_to, offset + total + j);
                    _tokenIdTrackers[i].increment();
                }
            }
        }
    }

    function _mintAnElement(address _to, uint256 id) private {
        _safeMint(_to, id);
        emit CreateImpactToken(id);
    }

    function mintUnique(address _to, uint256 id) public payable onlyOwner {
        _safeMint(_to, id);
        emit CreateImpactToken(id);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _hiddenURI() public view virtual returns (string memory) {
        return hiddenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function setHiddenURI(string memory __hiddenURI) public onlyOwner {
        hiddenURI = __hiddenURI;
    }

    function setWithdrawAllAddress(address withdrwAddr) public onlyOwner {
        withdrawAllAddress = withdrwAddr;
    }

    function setMarketplaceContract(address _marketplaceContract) public onlyOwner {
        marketplaceContract = _marketplaceContract;
    }

    function getHiddenURI() public view onlyOwner returns (string memory) {
        return hiddenURI;
    }

    function reveal() public onlyOwner {
        isRevealed = true;
    }

    function hide() public onlyOwner {
        isRevealed = false;
    }

    function _isRevealed() public pure returns(bool) {
        return true;
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (!_isRevealed()) {
            return _hiddenURI();
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
        _widthdraw(withdrawAllAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getDonorMaxElements() public view returns (uint256) {
        return DONOR_MAX_ELEMENTS;
    }

    function getGmMaxElements() public view returns (uint256) {
        return GM_MAX_ELEMENTS;
    }

    function getWagmiMaxElements() public view returns (uint256) {
        return WAGMI_MAX_ELEMENTS;
    }
    
    function getDonorPrice() public view returns (uint256) {
        return DONOR_PRICE;
    }

    function getGmPrice() public view returns (uint256) {
        return GM_PRICE;
    }

    function getWagmiPrice() public view returns (uint256) {
        return WAGMI_PRICE;
    }

    function setDonorMaxElements(uint256 newMax) public onlyOwner {
        DONOR_MAX_ELEMENTS = newMax;
    }

    function setGmMaxElements(uint256 newMax) public onlyOwner {
        GM_MAX_ELEMENTS = newMax;
    }

    function setWagmiMaxElements(uint256 newMax) public onlyOwner {
        WAGMI_MAX_ELEMENTS = newMax;
    }

    function setDonorPrice(uint256 newPrice) public onlyOwner {
        DONOR_PRICE = newPrice;
    }
    
    function setGmPrice(uint256 newPrice) public onlyOwner {
        GM_PRICE = newPrice;
    }

    function setWagmiPrice(uint256 newPrice) public onlyOwner {
        WAGMI_PRICE = newPrice;
    }
}