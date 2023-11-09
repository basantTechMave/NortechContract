// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract Oracle {
    address public owner; // The owner of the oracle contract
    uint256 public assetPrice; // The latest asset price retrieved from an external source

    event AssetPriceUpdated(uint256 newPrice);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function updateAssetPrice(uint256 newPrice) external onlyOwner {
        assetPrice = newPrice;
        emit AssetPriceUpdated(newPrice);
    }

    function getAssetPrice() external view returns (uint256) {
        return assetPrice;
    }
}
