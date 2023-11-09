// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IDMarketplaceContract is Ownable {
    ERC721Enumerable[] private supportedNFTContracts;
    
    
    uint256 public listingPrice = 1 ether;

    struct Listing {
        address payable seller;
        uint256 tokenId;
        uint256 price;
        address nftContract;
        bool active;
    }

    mapping(uint256 => Listing) public listings;

    event ListingCreated(address indexed seller, uint256 indexed tokenId, uint256 price, address indexed nftContract);
    event ListingRemoved(uint256 indexed tokenId);
    event ListingPurchased(address indexed buyer, uint256 indexed tokenId);
    
    constructor(address[] memory _supportedNFTContracts,address initialOwner) Ownable(initialOwner) {
        for (uint256 i = 0; i < _supportedNFTContracts.length; i++) {
            supportedNFTContracts.push(ERC721Enumerable(_supportedNFTContracts[i]));
        }
    }

    modifier onlyNFTOwner(uint256 tokenId, address nftContract) {
        require(isNFTContractSupported(nftContract), "NFT contract not supported");
        require(supportedNFTContracts[getNFTContractIndex(nftContract)].ownerOf(tokenId) == msg.sender, "You must own the NFT");
        _;
    }

    modifier listingExists(uint256 tokenId, address nftContract) {
        require(listings[tokenId].seller != address(0) && listings[tokenId].nftContract == nftContract, "Listing does not exist");
        _;
    }

    modifier onlySeller(uint256 tokenId, address nftContract) {
        require(listings[tokenId].seller == msg.sender && listings[tokenId].nftContract == nftContract, "You are not the seller");
        _;
    }

    function isNFTContractSupported(address nftContract) internal view returns (bool) {
        for (uint256 i = 0; i < supportedNFTContracts.length; i++) {
            if (address(supportedNFTContracts[i]) == nftContract) {
                return true;
            }
        }
        return false;
    }

    function getNFTContractIndex(address nftContract) internal view returns (uint256) {
        for (uint256 i = 0; i < supportedNFTContracts.length; i++) {
            if (address(supportedNFTContracts[i]) == nftContract) {
                return i;
            }
        }
        revert("NFT contract not found");
    }

    function createListing(uint256 tokenId, uint256 price, address nftContract) external onlyNFTOwner(tokenId, nftContract) {
        require(price > 0, "Price must be greater than 0");
        supportedNFTContracts[getNFTContractIndex(nftContract)].transferFrom(msg.sender, address(this), tokenId);
        listings[tokenId] = Listing({
            seller: payable(msg.sender),
            tokenId: tokenId,
            price: price,
            nftContract: nftContract,
            active: true
        });
        emit ListingCreated(msg.sender, tokenId, price, nftContract);
    }

    function removeListing(uint256 tokenId, address nftContract) external onlySeller(tokenId, nftContract) listingExists(tokenId, nftContract) {
        supportedNFTContracts[getNFTContractIndex(nftContract)].transferFrom(address(this), msg.sender, tokenId);
        delete listings[tokenId];
        emit ListingRemoved(tokenId);
    }

    function buyListing(uint256 tokenId, address nftContract) external payable listingExists(tokenId, nftContract) {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Listing is no longer active");
        require(msg.value == listing.price, "Incorrect payment amount");

        listing.active = false;
        listing.seller.transfer(listing.price);
        supportedNFTContracts[getNFTContractIndex(nftContract)].transferFrom(address(this), msg.sender, tokenId);
        emit ListingRemoved(tokenId);
        emit ListingPurchased(msg.sender, tokenId);
    }

    function setListingPrice(uint256 newPrice) external onlyOwner {
        listingPrice = newPrice;
    }

    function addSupportedNFTContract(address nftContract) external onlyOwner {
        require(!isNFTContractSupported(nftContract), "NFT contract is already supported");
        supportedNFTContracts.push(ERC721Enumerable(nftContract));
    }

    function removeSupportedNFTContract(address nftContract) external onlyOwner {
        uint256 index = getNFTContractIndex(nftContract);
        supportedNFTContracts[index] = supportedNFTContracts[supportedNFTContracts.length - 1];
        supportedNFTContracts.pop();
    }
}