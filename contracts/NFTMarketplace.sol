// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

// Internal imports from OpenZeppelin contracts
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "hardhat/console.sol";

// NFT Marketplace contract, inheriting ERC721URIStorage from OpenZeppelin
contract NFTMarketplace is ERC721URIStorage {
    // Using Counters library to track token and item IDs
    using Counters for Counters.Counter;

    // State variables to track token and item counters
    Counters.Counter private _tokenIds; // Counter for unique token IDs
    Counters.Counter private _itemsSold; // Counter for items sold

    address payable owner; // Owner of the marketplace contract
    uint256 listingPrice = 0.0015 ether; // Listing fee for adding an item to the marketplace

    // Mapping to track MarketItem details by token ID
    mapping(uint256 => MarketItem) private idMarketItem;

    // Struct to represent a market item with its properties
    struct MarketItem {
        uint256 tokenId; // Unique token ID of the NFT
        address payable seller; // Address of the seller listing the item
        address payable owner; // Address of the current owner (could be contract or buyer)
        uint256 price; // Price of the listed item
        bool sold; // Whether the item is sold or not
    }

    // Event to be emitted when a market item is created
    event idMarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    // Modifier to ensure only the owner of the contract can perform certain actions
    modifier onlyOwner() {
        require(owner == msg.sender, "only owner can do certain actions");
        _;
    }

    // Constructor to set the contract owner and initialize the ERC721 token
    constructor() ERC721("NFT Metaverse Token", "MYNFT") {
        owner = payable(msg.sender); // Assign contract deployer as owner
    }

    // Function to update the listing price, only accessible by the owner
    function updateListingPrice(
        uint256 _listingPrice
    ) external payable onlyOwner {
        listingPrice = _listingPrice; // Update listing price with new value
    }

    // Public view function to get the current listing price
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    // Function to create a new token and list it in the marketplace
    function createToken(
        string memory tokenURI,
        uint256 price
    ) public payable returns (uint256) {
        _tokenIds.increment(); // Increment the token ID counter
        uint256 new_tokenId = _tokenIds.current(); // Get the current token ID
        _mint(msg.sender, new_tokenId); // Mint a new token to the caller
        _setTokenURI(new_tokenId, tokenURI); // Set the token URI (metadata)
        createMarketItem(new_tokenId, price); // Create a market item for the token
        return new_tokenId;
    }

    // Internal function to create a market item for a newly created token
    function createMarketItem(uint256 tokenId, uint256 price) private {
        require(price > 0, "price must at least 1"); // Ensure the price is greater than 0
        require(
            msg.value == listingPrice,
            "price must be equal to listing price"
        ); // Ensure the listing price is paid

        // Add the item to the market
        idMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender), // Seller is the caller of the function
            payable(address(this)), // Ownership transferred to the contract for listing
            price,
            false // Initially, the item is not sold
        );

        // Transfer the token from seller to the marketplace contract
        _transfer(msg.sender, address(this), tokenId);

        // Emit the item creation event
        emit idMarketItemCreated(
            tokenId,
            msg.sender,
            address(this),
            price,
            false
        );
    }

    // Function to allow the owner of an item to relist it in the marketplace
    function reSellToken(uint256 tokenId, uint256 price) public payable {
        require(
            idMarketItem[tokenId].owner == msg.sender,
            "Only Item owners can operate"
        ); // Ensure only the item owner can relist
        require(
            msg.value == listingPrice,
            "value must be equal to listing price"
        ); // Ensure listing price is paid again

        // Update market item status for reselling
        idMarketItem[tokenId].sold = false;
        idMarketItem[tokenId].price = price;
        idMarketItem[tokenId].seller = payable(msg.sender);
        idMarketItem[tokenId].owner = payable(address(this));

        _itemsSold.decrement(); // Decrement the items sold counter
        _transfer(msg.sender, address(this), tokenId); // Transfer the token back to the marketplace
    }

    // Function to create a market sale for an item listed in the marketplace
    function createMarketSale(uint256 tokenId) public payable {
        uint256 price = idMarketItem[tokenId].price; // Get the price of the item
        require(
            msg.value == price,
            "Please submit the asking price to complete the purchase"
        ); // Ensure the buyer pays the correct price

        // Transfer ownership and update item status
        idMarketItem[tokenId].owner = payable(msg.sender);
        idMarketItem[tokenId].sold = true;
        idMarketItem[tokenId].owner = payable(address(0)); // Reset ownership to empty address

        _itemsSold.increment(); // Increment the items sold counter
        _transfer(address(this), msg.sender, tokenId); // Transfer the token from marketplace to buyer

        // Transfer payments to marketplace owner and seller
        payable(owner).transfer(listingPrice);
        payable(idMarketItem[tokenId].seller).transfer(msg.value);
    }

    // Function to fetch all unsold market items
    function fetchMarketItem() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current(); // Get the total number of items created
        uint256 unSoldItemCount = _tokenIds.current() - _itemsSold.current(); // Calculate the number of unsold items
        uint256 currentIndex = 0;

        // Array to store unsold market items
        MarketItem[] memory items = new MarketItem[](unSoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idMarketItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Function to fetch the NFTs owned by the caller
    function fetchMyNFT() public view returns (MarketItem[] memory) {
        uint256 totalCount = _tokenIds.current(); // Get total number of tokens created
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // Count how many NFTs the caller owns
        for (uint256 i = 0; i < totalCount; i++) {
            if (idMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        // Array to store caller's owned NFTs
        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalCount; i++) {
            if (idMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Function to fetch the NFTs listed by the caller
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalCount = _tokenIds.current(); // Get total number of tokens created
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // Count how many items the caller has listed for sale
        for (uint256 i = 0; i < totalCount; i++) {
            if (idMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        // Array to store caller's listed NFTs
        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalCount; i++) {
            if (idMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
