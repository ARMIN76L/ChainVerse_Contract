// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PlatformManager {
    address public owner;
    uint256 public platformFeePercentage;

    // Event for fee updates
    event PlatformFeeUpdated(uint256 newFeePercentage);
    event FeeRecipientUpdated(address newRecipient);

    constructor(uint256 _initialFeePercentage) {
        owner = msg.sender;
        platformFeePercentage = _initialFeePercentage;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute this");
        _;
    }

    // Update the platform fee percentage (for example, 5% fee would be 50)
    function updatePlatformFee(uint256 newFeePercentage) public onlyOwner {
        require(newFeePercentage <= 1000, "Fee percentage cannot exceed 1000");
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(newFeePercentage);
    }

    // Transfer ownership to another address
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
