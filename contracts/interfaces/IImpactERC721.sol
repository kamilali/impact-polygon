// SPDX-License-Identifier:MIT
pragma solidity ^0.8.4;

interface IImpactERC721 {
    function mint(address _to, uint256 _count) external payable;
    function mintAnElement(address _to) external payable;
}