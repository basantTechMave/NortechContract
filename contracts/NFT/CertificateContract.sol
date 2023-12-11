// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title CertificateContract
 * @dev A smart contract for issuing and managing certificates on the Ethereum blockchain.
 */
contract CertificateContract is Initializable, ERC721URIStorageUpgradeable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Custom event for certificate issuance
    event CertificateIssued(address indexed recipient, uint256 tokenId, string uri, address indexed issuer);

    // Enum representing the status of a certificate
    enum CertificateStatus { Valid, Revoked, Expired }

    // Mapping to store the status of each certificate
    mapping(uint256 => CertificateStatus) private certificateStatus;

    /**
     * @dev Initializes the contract with the given parameters.
     * @param name The name of the certificate token.
     * @param symbol The symbol of the certificate token.
     * @param initialOwner The initial owner of the contract with admin and minter roles.
     */
    function initialize(string memory name, string memory symbol, address initialOwner) public initializer {
        __ERC721_init(name, symbol);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);
    }

    /**
     * @dev Authorizes an upgrade and checks if the caller is the owner.
     * @param newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}

    /**
     * @dev Sets the URI for a certificate token.
     * @param tokenId The ID of the certificate token.
     * @param uri The URI to be set.
     */
    function setCertificateURI(uint256 tokenId, string memory uri) external onlyOwner {
        ownerOf(tokenId); // Check if the token exists and get the owner
        _setTokenURI(tokenId, uri);
    }

    /**
     * @dev Updates the URI for a certificate token.
     * @param tokenId The ID of the certificate token.
     * @param newUri The new URI to be set.
     */
    function updateCertificateURI(uint256 tokenId, string memory newUri) external onlyOwner {
        ownerOf(tokenId); // Check if the token exists and get the owner
        // Additional conditions for updating URI (e.g., time-based conditions, permission checks)
        // Add your conditions here

        _setTokenURI(tokenId, newUri);
    }

    /**
     * @dev Issues a new certificate to a recipient.
     * @param recipient The address of the recipient.
     * @param tokenId The ID of the certificate token.
     * @param uri The URI of the certificate token.
     */
    function issueCertificate(address recipient, uint256 tokenId, string memory uri) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have MINTER_ROLE to mint");
        ownerOf(tokenId); // Check if the token exists and get the owner

        // Ensure that the URI is not empty
        require(bytes(uri).length > 0, "URI cannot be empty");

        _mint(recipient, tokenId);
        _setTokenURI(tokenId, uri);
        certificateStatus[tokenId] = CertificateStatus.Valid;

        // Emit custom certificate issuance event
        emit CertificateIssued(recipient, tokenId, uri, msg.sender);
    }

    /**
     * @dev Issues multiple certificates in a batch to different recipients.
     * @param recipients The addresses of the recipients.
     * @param tokenIds The IDs of the certificate tokens.
     * @param uris The URIs of the certificate tokens.
     */
    function batchIssueCertificates(address[] calldata recipients, uint256[] calldata tokenIds, string[] calldata uris) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have MINTER_ROLE to batch mint");

        require(recipients.length == tokenIds.length && recipients.length == uris.length, "Input arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 tokenId = tokenIds[i];
            string memory uri = uris[i];

            // Ensure that the URI is not empty
            require(bytes(uri).length > 0, "URI cannot be empty");

            _mint(recipients[i], tokenId);
            _setTokenURI(tokenId, uri);
            certificateStatus[tokenId] = CertificateStatus.Valid;

            // Emit custom certificate issuance event for each token
            emit CertificateIssued(recipients[i], tokenId, uri, msg.sender);
        }
    }

    /**
     * @dev Explicitly overrides the supportsInterface function from ERC165.
     * @param interfaceId The ID of the interface.
     * @return A boolean indicating whether the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable, ERC721URIStorageUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Revokes a certificate by setting its status to Revoked.
     * @param tokenId The ID of the certificate token to be revoked.
     */
    function revokeCertificate(uint256 tokenId) external onlyOwner {
        ownerOf(tokenId);
        certificateStatus[tokenId] = CertificateStatus.Revoked;
    }

    /**
     * @dev Gets the status of a certificate.
     * @param tokenId The ID of the certificate token.
     * @return The status of the certificate.
     */
    function getCertificateStatus(uint256 tokenId) external view returns (CertificateStatus) {
        ownerOf(tokenId);
        return certificateStatus[tokenId];
    }
}
