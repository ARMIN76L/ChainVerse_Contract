// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PlatformManager.sol";

contract ChainVerse is ReentrancyGuard {
    // Define article categories as an enum
    enum Category {
        Technology,
        Business,
        Health,
        Science,
        Education,
        Art_Culture,
        Entertainment,
        Sports,
        Travel,
        Lifestyle,
        Food,
        Politics,
        Finance,
        Environment,
        History
    }

    struct Article {
        string title;
        string ipfsHash;
        string imageIpfsHash;
        Category category;
        address author;
        uint256 timestamp;
        uint256 price; // Price in wei for reading
    }

    PlatformManager public platformManager;

    // Use a mapping instead of an array for storing articles
    mapping(uint256 => Article) public articles; // Maps articleId to Article
    uint256 public nextArticleId; // Keeps track of the next available article ID

    // Mapping to track which users have paid for which articles
    mapping(uint256 => mapping(address => bool)) public hasPaid;

    // Track accumulated platform fees
    uint256 public accumulatedPlatformFees;

    // Track accumulated earnings for each author
    mapping(address => uint256) public authorEarnings;

    // Event for new article
    event NewArticle(
        uint256 indexed articleId,
        address indexed author,
        string title,
        uint256 price,
        Category indexed category
    );

    // Event for article access
    event ArticleAccessed(uint256 articleId, address indexed reader);

    // Event for successful payment
    event PaymentProcessed(
        uint256 articleId,
        address indexed payer,
        uint256 amount,
        uint256 platformFee,
        uint256 authorAmount
    );

    // Event for payment failure
    event PaymentFailed(
        uint256 articleId,
        address indexed payer,
        string reason
    );

    // Event for refund
    event RefundIssued(
        uint256 articleId,
        address indexed payer,
        uint256 amount
    );

    uint256 public refundPeriod = 1 days;

    constructor(address _platformManager) {
        platformManager = PlatformManager(_platformManager);
    }

    // Publish a new article
    function publishArticle(
        string memory _title,
        string memory _ipfsHash,
        string memory _imageIpfsHash,
        Category _category,
        uint256 _price
    ) public {
        require(bytes(_title).length <= 64, "Title exceeds max length");
        require(
            bytes(_ipfsHash).length == 46 || bytes(_ipfsHash).length == 59,
            "Invalid IPFS hash length"
        );

        uint256 articleId = nextArticleId; // Use next available ID
        articles[articleId] = Article({
            title: _title,
            ipfsHash: _ipfsHash,
            imageIpfsHash: _imageIpfsHash,
            category: _category,
            author: msg.sender,
            timestamp: block.timestamp,
            price: _price
        });

        nextArticleId++; // Increment for the next article
        emit NewArticle(articleId, msg.sender, _title, _price, _category);
    }

    // Pay to access an article
    function payForArticle(uint256 articleId) public payable nonReentrant {
        require(articleId < nextArticleId, "Article does not exist");
        Article memory article = articles[articleId];
        require(article.price > 0, "This article is free");
        require(msg.value >= article.price, "Insufficient funds sent");

        // Calculate platform fee
        uint256 platformFee = (msg.value *
            platformManager.platformFeePercentage()) / 1000;
        uint256 authorAmount = msg.value - platformFee;

        // Accumulate platform fee in the contract
        accumulatedPlatformFees += platformFee;

        // Accumulate author earnings
        authorEarnings[article.author] += authorAmount;

        // Mark the user as having paid for the article
        hasPaid[articleId][msg.sender] = true;

        // Log successful payment
        emit PaymentProcessed(
            articleId,
            msg.sender,
            msg.value,
            platformFee,
            authorAmount
        );

        emit ArticleAccessed(articleId, msg.sender);
    }

    // Allow the owner of PlatformManager to withdraw platform fees
    function withdrawPlatformFees() public nonReentrant {
        require(
            msg.sender == platformManager.owner(),
            "Only the owner can withdraw platform fees"
        );
        require(accumulatedPlatformFees > 0, "No platform fees to withdraw");
        uint256 feesToWithdraw = accumulatedPlatformFees;

        // Ensure the contract has enough balance to cover the withdrawal
        require(
            address(this).balance >= feesToWithdraw,
            "Insufficient contract balance"
        );

        accumulatedPlatformFees = 0;

        (bool success, ) = payable(msg.sender).call{value: feesToWithdraw}("");
        require(success, "Withdrawal failed");
    }

    // Allow authors to withdraw their accumulated earnings
    function withdrawEarnings() public nonReentrant {
        uint256 earnings = authorEarnings[msg.sender];
        require(earnings > 0, "No earnings to withdraw");

        // Ensure the contract has enough balance to cover the withdrawal
        require(
            address(this).balance >= earnings,
            "Insufficient contract balance"
        );

        // Reset author's earnings before transfer
        authorEarnings[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: earnings}("");
        require(success, "Withdrawal failed");
    }

    // Check if a user can access an article
    function canAccessArticle(
        uint256 articleId,
        address user
    ) public view returns (bool) {
        return hasPaid[articleId][user];
    }

    function getArticleDetails(
        uint256 articleId
    )
        public
        view
        returns (
            string memory title,
            string memory imageIpfsHash,
            Category category,
            address author,
            uint256 timestamp,
            uint256 price,
            bool hasAccess
        )
    {
        require(articleId < nextArticleId, "Article does not exist");
        Article memory article = articles[articleId];
        if (article.price == 0) {
            hasAccess = true;
        } else {
            hasAccess = hasPaid[articleId][msg.sender];
        }
        return (
            article.title,
            article.imageIpfsHash,
            article.category,
            article.author,
            article.timestamp,
            article.price,
            hasAccess
        );
    }

    // Get the IPFS hash of an article (only accessible if the user has paid)
    function getArticleContent(
        uint256 articleId
    ) public view returns (string memory ipfsHash) {
        require(articleId < nextArticleId, "Article does not exist");
        Article memory article = articles[articleId];

        // Allow free access to free articles
        if (article.price == 0) {
            return article.ipfsHash;
        }

        // For paid articles, check if the user has paid
        require(
            hasPaid[articleId][msg.sender],
            "You need to pay to access this article"
        );

        return article.ipfsHash;
    }

    // Function to allow free articles (if price is set to 0)
    function freeArticle(
        uint256 articleId
    ) public view returns (string memory ipfsHash) {
        require(articleId < nextArticleId, "Article does not exist");
        Article memory article = articles[articleId];
        require(article.price == 0, "This article is not free");
        return article.ipfsHash;
    }

    receive() external payable {}
}
