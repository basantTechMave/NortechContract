// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title Oracle
 * @dev A decentralized upgradeable oracle contract for retrieving and updating asset prices.
 */
contract Oracle is Initializable, AccessControlUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant NODE_ROLE = keccak256("NODE_ROLE");

    uint256 public constant REQUIRED_SIGNATURES = 2; // Number of required signatures for multi-signature

    address public owner; // The owner of the oracle contract
    uint256 public assetPrice; // The latest asset price retrieved from authorized nodes
    uint256 public lastUpdateTimestamp; // Timestamp of the last asset price update
    uint256 public numberOfResponses; // Number of responses received from authorized nodes

    // Secondary oracle contract
    Oracle public secondaryOracle;
    bool public useSecondaryOracle;

    address[] public signedNodes;
    uint256 public signaturesCount;

    event AssetPriceUpdated(uint256 newPrice, uint256 timestamp);
    event SecondaryOracleActivated(address secondaryOracle);

    /**
     * @dev Modifier to restrict access to the admin role only.
     */
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Must have admin role");
        _;
    }

    /**
     * @dev Modifier to restrict access to the node role only.
     */
    modifier onlyNode() {
        require(hasRole(NODE_ROLE, msg.sender), "Must have node role");
        _;
    }

    /**
     * @dev Initializer to set up the Oracle contract.
     */
    function initialize(address _owner) public initializer {
        __AccessControl_init();
        owner = _owner;
        // _setupRole(ADMIN_ROLE, _owner);
        // _setupRole(NODE_ROLE, _owner);
    }

    /**
     * @dev Updates the asset price with the new value provided by authorized nodes.
     * @param newPrice The new asset price.
     * @param v The recovery id (part of the signature).
     * @param r The R component of the signature.
     * @param s The S component of the signature.
     */
    function updateAssetPrice(uint256 newPrice, uint8 v, bytes32 r, bytes32 s) external onlyNode {
        // Check that the new price is within reasonable bounds
        require(newPrice > 0, "Invalid price: must be greater than 0");

        // Verify the signature to ensure data integrity
        bytes32 messageHash = keccak256(abi.encodePacked(newPrice, signedNodes));
        require(ecrecover(messageHash, v, r, s) == owner, "Invalid signature");

        // Check for reasonable changes in asset price to prevent erroneous updates
        require(newPrice > assetPrice * 95 / 100 && newPrice < assetPrice * 105 / 100, "Invalid price change");

        // Check if the node has not signed before
        require(!hasSigned(msg.sender), "Node has already signed");

        // Mark the node as signed
        signedNodes.push(msg.sender);
        signaturesCount++;

        // Check if the required number of signatures is reached
        if (signaturesCount >= REQUIRED_SIGNATURES) {
            applyUpdate(newPrice);
        }
    }

    /**
     * @dev Applies the asset price update after validating the required number of signatures.
     * @param newPrice The new asset price.
     */
    function applyUpdate(uint256 newPrice) internal {
        // Reset the signed nodes array
        delete signedNodes;

        // Update the asset price
        assetPrice = newPrice;
        lastUpdateTimestamp = block.timestamp; // Record the timestamp of the update
        numberOfResponses++;
        emit AssetPriceUpdated(newPrice, lastUpdateTimestamp);

        // Reset the signatures count
        signaturesCount = 0;
    }

    /**
     * @dev Checks if a node has already signed the update.
     * @param node The address of the node.
     * @return True if the node has signed, false otherwise.
     */
    function hasSigned(address node) internal view returns (bool) {
        for (uint256 i = 0; i < signedNodes.length; i++) {
            if (signedNodes[i] == node) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Gets the latest asset price.
     * @return The latest asset price.
     */
    function getAssetPrice() external view returns (uint256) {
        return assetPrice;
    }

    /**
     * @dev Gets the timestamp of the last asset price update.
     * @return The timestamp of the last update.
     */
    function getLastUpdateTimestamp() external view returns (uint256) {
        return lastUpdateTimestamp;
    }

    /**
     * @dev Adds an address to the node role (authorized nodes).
     * @param node The address of the node to be authorized.
     */
    function addAuthorizedNode(address node) external onlyAdmin {
        grantRole(NODE_ROLE, node);
    }

    /**
     * @dev Removes an address from the node role (deauthorized node).
     * @param node The address of the node to be deauthorized.
     */
    function removeAuthorizedNode(address node) external onlyAdmin {
        revokeRole(NODE_ROLE, node);
    }

    /**
     * @dev Activates the secondary oracle in case of issues with the primary oracle.
     * @param _secondaryOracle Address of the secondary oracle contract.
     */
    function activateSecondaryOracle(address _secondaryOracle) external onlyAdmin {
        require(_secondaryOracle != address(0), "Invalid secondary oracle address");
        useSecondaryOracle = true;
        secondaryOracle = Oracle(_secondaryOracle);
        emit SecondaryOracleActivated(_secondaryOracle);
    }

    /**
     * @dev Switches back to the primary oracle after resolving the issues.
     */
    function deactivateSecondaryOracle() external onlyAdmin {
        useSecondaryOracle = false;
    }

    /**
     * @dev Gets the status of the secondary oracle.
     * @return True if the secondary oracle is active, false otherwise.
     */
    function isSecondaryOracleActive() external view returns (bool) {
        return useSecondaryOracle;
    }
}
