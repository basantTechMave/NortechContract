// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract NNTHTokenRoles {
    address public admin;
    address public pauser;
    address public minter;
    address public burner;
    address public locker;

    constructor() {
        admin = msg.sender;
        pauser = msg.sender;
        minter = msg.sender;
        burner = msg.sender;
        locker = msg.sender;
    }

    
    /**
     * @dev Modifier to check if the sender is the admin or an authorized entity.
     */
    modifier onlyAdminOrAuthorized() {
        require(msg.sender == admin || msg.sender == address(this), "Not authorized");
        _;
    }

    /**
     * @dev Modifier to check if the sender is the pauser or an authorized entity.
     */
    modifier onlyPauserOrAuthorized() {
        require(msg.sender == pauser || msg.sender == address(this), "Not authorized");
        _;
    }

    /**
     * @dev Modifier to check if the sender is the minter or an authorized entity.
     */
    modifier onlyMinterOrAuthorized() {
        require(msg.sender == minter || msg.sender == address(this), "Not authorized");
        _;
    }

    /**
     * @dev Modifier to check if the sender is the burner or an authorized entity.
     */
    modifier onlyBurnerOrAuthorized() {
        require(msg.sender == burner || msg.sender == address(this), "Not authorized");
        _;
    }

    /**
     * @dev Modifier to check if the sender is the locker or an authorized entity.
     */
    modifier onlyLockerOrAuthorized() {
        require(msg.sender == locker || msg.sender == address(this), "Not authorized");
        _;
    }
}
