// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ChainVerse.sol";
import "../src/PlatformManager.sol";

contract ChainVerseTest is Test {
    ChainVerse chainVerse;
    PlatformManager platformManager;
    address author = address(0x1);
    address reader = address(0x2);
    address owner = address(0x1234);

    function setUp() public {
        platformManager = new PlatformManager(100);
        chainVerse = new ChainVerse(address(platformManager));

        vm.deal(author, 10 ether);
        vm.deal(reader, 10 ether);

        vm.prank(platformManager.owner());
        platformManager.transferOwnership(owner);
    }

    function testPublishArticle() public {
        string memory title = "Sample Title";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, ipfsHash, price);

        (string memory returnedTitle, , , uint256 returnedPrice, ) = chainVerse
            .getArticleDetails(0);
        assertEq(returnedTitle, title);
        assertEq(returnedPrice, price);
    }

    function testFailPublishArticleWithLongTitle() public {
        string
            memory longTitle = "This title is longer than 64 characters. It should trigger an error.";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(longTitle, ipfsHash, price);
    }

    function testFailPublishArticleWithInvalidIPFSHash() public {
        string memory title = "Valid Title";
        string memory invalidIpfsHash = "QmInvalidHash";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, invalidIpfsHash, price);
    }

    function testPayForArticle() public {
        string memory title = "Sample Title";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, ipfsHash, price);

        vm.prank(reader);
        chainVerse.payForArticle{value: 1 ether}(0);

        bool hasPaid = chainVerse.canAccessArticle(0, reader);
        assertEq(hasPaid, true);
    }

    function testFailPayForArticleWithInsufficientFunds() public {
        string memory title = "Sample Title";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, ipfsHash, price);

        vm.prank(reader);
        chainVerse.payForArticle{value: 0.5 ether}(0);
    }

    function testRequestRefundWithinPeriod() public {
        string memory title = "Sample Title";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, ipfsHash, price);

        vm.prank(reader);
        chainVerse.payForArticle{value: 1 ether}(0);

        vm.warp(block.timestamp + 1 hours);

        vm.prank(reader);
        chainVerse.requestRefund(0);

        bool hasPaid = chainVerse.canAccessArticle(0, reader);
        assertEq(hasPaid, false);
    }

    function testRequestRefundAfterPeriod() public {
        string memory title = "Sample Title";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, ipfsHash, price);

        vm.prank(reader);
        chainVerse.payForArticle{value: 1 ether}(0);

        vm.warp(block.timestamp + 2 days);

        vm.prank(reader);
        vm.expectRevert("Refund period expired");
        chainVerse.requestRefund(0);
    }

    function testAccessArticleContent() public {
        string memory title = "Sample Title";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, ipfsHash, price);

        vm.prank(reader);
        chainVerse.payForArticle{value: 1 ether}(0);

        vm.prank(reader);
        string memory content = chainVerse.getArticleContent(0);
        assertEq(content, ipfsHash);
    }

    function testWithdrawPlatformFees() public {
        string memory title = "Sample Title";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, ipfsHash, price);

        vm.prank(reader);
        chainVerse.payForArticle{value: 1 ether}(0);

        uint256 platformBalanceBefore = address(chainVerse).balance;
        assert(platformBalanceBefore > 0);

        vm.prank(platformManager.owner());
        chainVerse.withdrawPlatformFees();

        uint256 platformBalanceAfter = address(chainVerse).balance;
        assert(platformBalanceAfter < platformBalanceBefore);
    }

    function testWithdrawAuthorEarnings() public {
        string memory title = "Sample Title";
        string
            memory ipfsHash = "Qm12345678901234567890123456789012345678901234";
        uint256 price = 1 ether;

        vm.prank(author);
        chainVerse.publishArticle(title, ipfsHash, price);

        vm.prank(reader);
        chainVerse.payForArticle{value: 1 ether}(0);

        uint256 authorBalanceBefore = author.balance;
        uint256 authorEarnings = chainVerse.authorEarnings(author);

        vm.prank(author);
        chainVerse.withdrawEarnings();

        assertEq(author.balance, authorBalanceBefore + authorEarnings);
    }
}
