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

contract ImpactNFT is ERC721Enumerable, Ownable, ERC721Burnable, ERC721Pausable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdTracker;

    uint256 public constant MAX_ELEMENTS = 8888;    // The max number of elements in the collection
    uint256 public constant PRICE = 0.04 ether;     // Base price per mint
    uint256 public constant MAX_BY_MINT = 20;       // Max number of mints per transaction
    string public baseTokenURI;                     // Base token URI of collection.. should be ipfs://{HASH}/
    string public hiddenURI;                        // Token URI of hidden object
    bool public isRevealed = false;                 // Determines if the token is revealed
    
    address private marketplaceContract;
    address private withdrawAllAddress;

    event CreateImpactToken(uint256 indexed id);
    
    constructor(string memory baseURI, string memory __hiddenURI, address _withdrawAllAddress, address _marketplaceContract) ERC721("ImpactNFT", "IMPACT") {
        _pause();
        setBaseURI(baseURI);
        setHiddenURI(__hiddenURI);
        setWithdrawAllAddress(_withdrawAllAddress);
        marketplaceContract = _marketplaceContract;
    }

    modifier saleIsOpen {
        // Reqiure that the total supply is less than or euqal to the number of max elements
        require(_totalSupply() <= MAX_ELEMENTS, "Sale end");

        // If someone NOT the owner and is interacting with the contract, require that the contract is not paused
        if (_msgSender() != owner()) require(!paused(), "Pausable: paused");
        _;
    }

    modifier allowedMinters {
        require(_msgSender() == owner() || _msgSender() == marketplaceContract);
        _;
    }

    function _totalSupply() internal view returns (uint) {
        return _tokenIdTracker.current();
    }

    function mint(address _to, uint256 _count) public payable saleIsOpen {
        uint256 total = _totalSupply();
        require(total + _count <= MAX_ELEMENTS, "Max limit");
        require(_count <= MAX_BY_MINT, "Exceeds number");
        require(msg.value >= price(_count), "Value below price");

        for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(_to);
        }
    }

    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        require(id + 1 <= MAX_ELEMENTS, "Max limit has been reached");
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateImpactToken(id);
    }
    
    function mintAnElement(address _to) public payable allowedMinters {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateImpactToken(id);
    }

    function price(uint256 _count) public pure returns (uint256) {
        return PRICE.mul(_count);
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

    function getHiddenURI() public view onlyOwner returns (string memory) {
        return hiddenURI;
    }

    function reveal() public onlyOwner {
        isRevealed = true;
    }

    function hide() public onlyOwner {
        isRevealed = false;
    }

    function _isRevealed() public view returns(bool) {
        return isRevealed;
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
}
