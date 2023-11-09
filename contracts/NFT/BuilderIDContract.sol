// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BuilderIDContract is ERC721, Ownable {
    uint256 public nextTokenId;

    constructor(address initialOwner)
        ERC721("Builder ID NFT", "BID")
        Ownable(initialOwner)
    {
        nextTokenId = 1;
    }

    function mintBuilderID(address recipient) external onlyOwner {
        uint256 tokenId = nextTokenId;
        _mint(recipient, tokenId);
        nextTokenId++;
    }

    function burnBuilderID(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }
}
