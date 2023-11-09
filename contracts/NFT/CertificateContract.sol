// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CertificateContract is ERC721, Ownable {
    mapping(uint256 => string) private certificateURIs;
    mapping(uint256 => bool) private exists;

    constructor(string memory name, string memory symbol, address initialOwner)
        ERC721(name, symbol)
        Ownable(initialOwner)
    {}

    function setCertificateURI(uint256 tokenId, string memory uri) external onlyOwner {
        require(exists[tokenId], "Token does not exist");
        certificateURIs[tokenId] = uri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists[tokenId], "Token does not exist");
        return certificateURIs[tokenId];
    }

    function issueCertificate(address recipient, uint256 tokenId, string memory uri) external onlyOwner {
        require(!exists[tokenId], "Token ID already exists");
        _mint(recipient, tokenId);
        certificateURIs[tokenId] = uri;
        exists[tokenId] = true;
    }
}
