// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CategoryManagement is Ownable {

    // Mapping to track completion status of each category for a student
    mapping(address => mapping(uint8 => bool)) public hasCompletedCategory;


    /**
    * @dev Event emitted when the completion status of a category is set for a student.
    * @param student Address of the student.
    * @param category Category for which the completion status is set (1 to 5).
    * @param completed True if the student has completed the category, otherwise false.
    */
    event CategoryCompletionSet(address indexed student, uint8 indexed category, bool completed);

    /**
    * @dev Event emitted when the completion status of a category is removed for a student.
    * @param student Address of the student.
    * @param category Category for which the completion status is removed (1 to 5).
    */
    event CategoryCompletionRemoved(address indexed student, uint8 indexed category);

    constructor(address initialOwner) Ownable(initialOwner) {}


    /**
    * @dev Function to set the completion status of a category for a student.
    * @param student Address of the student.
    * @param category Category to set completion status (1 to 5).
    * @param completed True if the student has completed the category, otherwise false.
    */
    function setCategoryCompletion(address student, uint8 category, bool completed) external onlyOwner {
        require(category >= 1 && category <= 5, "Invalid category");
        // Check if the new status is different from the current status
        require(hasCompletedCategory[student][category] != completed, "Status is already set to the specified value");

        // Set completion status based on the category
        hasCompletedCategory[student][category] = completed;

        // Emit an event indicating that the completion status is set
        emit CategoryCompletionSet(student, category, completed);
    }

    /**
    * @dev Function to remove the completion status of a category for a student.
    * @param student Address of the student.
    * @param category Category to remove completion status (1 to 5).
    */
    function removeCategoryCompletion(address student, uint8 category) external onlyOwner {
        require(category >= 1 && category <= 5, "Invalid category");

        // Check if the current status is true before removing
        require(hasCompletedCategory[student][category], "Category completion status is not set");

        // Remove completion status based on the category
        hasCompletedCategory[student][category] = false;
        
        // Emit an event indicating that the completion status is removed
        emit CategoryCompletionRemoved(student, category);
    }
}
