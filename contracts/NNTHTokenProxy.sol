// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract NNTHTokenProxy {
    address public implementation;
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    constructor(address _implementation, address _admin) {
        implementation = _implementation;
        admin = _admin;
    }

    fallback() external payable {
        address _impl = implementation;
        assembly {
            // Delegatecall to the implementation contract
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 {
                revert(ptr, size)
            }
            default {
                return(ptr, size)
            }
        }
    }

    receive() external payable {
        // This is an empty receive function to satisfy the compiler warning
    }

    // Admin function to upgrade the implementation contract
    function upgradeImplementation(address newImplementation) external onlyAdmin {
        implementation = newImplementation;
    }
}
