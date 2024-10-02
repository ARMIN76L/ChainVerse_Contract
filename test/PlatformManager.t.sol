// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PlatformManager.sol";

contract PlatformManagerTest is Test {
    PlatformManager platformManager;
    address owner = address(0x1);
    address newOwner = address(0x2);

    function setUp() public {
        platformManager = new PlatformManager(100);
    }

    function testInitialize() public view {
        assertEq(platformManager.owner(), address(this));
        assertEq(platformManager.platformFeePercentage(), 100);
    }

    function testUpdatePlatformFee() public {
        platformManager.updatePlatformFee(200);
        assertEq(platformManager.platformFeePercentage(), 200);
    }

    function testFailUpdatePlatformFeeExceedsMax() public {
        platformManager.updatePlatformFee(1001);
    }

    function testOnlyOwnerCanUpdatePlatformFee() public {
        vm.prank(newOwner);
        vm.expectRevert("Only owner can execute this");
        platformManager.updatePlatformFee(200);
    }

    function testTransferOwnership() public {
        platformManager.transferOwnership(newOwner);
        assertEq(platformManager.owner(), newOwner);
    }

    function testFailTransferOwnershipToZeroAddress() public {
        platformManager.transferOwnership(address(0));
    }

    function testOnlyOwnerCanTransferOwnership() public {
        vm.prank(newOwner);
        vm.expectRevert("Only owner can execute this");
        platformManager.transferOwnership(newOwner);
    }
}
