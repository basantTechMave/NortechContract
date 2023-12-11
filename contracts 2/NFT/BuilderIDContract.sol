// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract BuilderIDContract is
    Initializable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Custom event for minting
    event BuilderIDMinted(address indexed recipient, uint256 tokenId, address indexed minter);

    // Custom event for burning
    event BuilderIDBurned(uint256 tokenId, address indexed burner);

    uint256 public nextTokenId;

    function initialize(address initialOwner) public initializer {
        __ERC721_init("Builder ID NFT", "BID");
        // __Ownable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have MINTER_ROLE to mint");
        _;
    }

    function mintBuilderID(address recipient, string memory tokenURI) external onlyMinter {
        uint256 tokenId = nextTokenId;
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);

        // Emit custom minting event
        emit BuilderIDMinted(recipient, tokenId, msg.sender);

        nextTokenId++;
    }

    function burnBuilderID(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved or not owner");
        _burn(tokenId);

        // Emit custom burning event
        emit BuilderIDBurned(tokenId, msg.sender);
    }

    function updateTokenURI(uint256 tokenId, string memory newTokenURI) external onlyOwner {
        _setTokenURI(tokenId, newTokenURI);
    }

    function grantMinterRole(address account) external onlyOwner {
        grantRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(address account) external onlyOwner {
        revokeRole(MINTER_ROLE, account);
    }

    // Explicitly override the supportsInterface function from ERC165
    function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable, ERC721URIStorageUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Corrected function to check if the caller is approved or the owner of the token
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        return _isApprovedOrOwner(spender, tokenId);
    }
}
