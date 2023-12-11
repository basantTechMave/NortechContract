// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title IDMarketplaceContract
 * @dev A decentralized marketplace contract for trading ERC721 NFTs.
 */
contract IDMarketplaceContract is Ownable, AccessControl, Pausable {
    ERC721Enumerable[] private supportedNFTContracts;

    uint256 public listingPrice = 1 ether;
    uint256 public commissionRate = 5; // 5% commission

    bytes32 public constant SUPPORT_ROLE = keccak256("SUPPORT_ROLE");

    struct Listing {
        address payable seller;
        uint256 tokenId;
        uint256 price;
        address nftContract;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(address => bool) public supportedNFTContractsMap;

    event ListingCreated(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price,
        address indexed nftContract,
        uint256 listingFee
    );

    event ListingRemoved(
        uint256 indexed tokenId,
        address indexed nftContract,
        uint256 price
    );

    event ListingPurchased(
        address indexed buyer,
        uint256 indexed tokenId,
        address indexed nftContract,
        uint256 price,
        uint256 commissionAmount
    );

    /**
     * @dev Contract constructor initializes roles and supported NFT contracts.
     * @param _supportedNFTContracts Addresses of the supported NFT contracts.
     * @param initialOwner Address of the initial owner of the contract.
     */
    constructor(address[] memory _supportedNFTContracts, address initialOwner) Ownable(initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(SUPPORT_ROLE, initialOwner);

        for (uint256 i = 0; i < _supportedNFTContracts.length; i++) {
            addSupportedNFTContract(_supportedNFTContracts[i]);
        }
    }

    /**
     * @dev Modifier to check if the caller is the owner of a specific NFT.
     * @param tokenId ID of the NFT.
     * @param nftContract Address of the NFT contract.
     */
    modifier onlyNFTOwner(uint256 tokenId, address nftContract) {
        require(isNFTContractSupported(nftContract), "NFT contract not supported");
        require(supportedNFTContractsMap[nftContract] && ERC721Enumerable(nftContract).ownerOf(tokenId) == msg.sender, "You must own the NFT");
        _;
    }

    /**
     * @dev Modifier to check if a listing exists for a specific NFT.
     * @param tokenId ID of the NFT.
     * @param nftContract Address of the NFT contract.
     */
    modifier listingExists(uint256 tokenId, address nftContract) {
        require(listings[tokenId].seller != address(0) && listings[tokenId].nftContract == nftContract, "Listing does not exist");
        _;
    }

    /**
     * @dev Modifier to check if the caller is the seller of a specific listing.
     * @param tokenId ID of the NFT.
     * @param nftContract Address of the NFT contract.
     */
    modifier onlySeller(uint256 tokenId, address nftContract) {
        require(listings[tokenId].seller == msg.sender && listings[tokenId].nftContract == nftContract, "You are not the seller");
        _;
    }

    /**
     * @dev Function to check if an NFT contract is supported.
     * @param nftContract Address of the NFT contract.
     * @return true if the NFT contract is supported, false otherwise.
     */
    function isNFTContractSupported(address nftContract) internal view returns (bool) {
        return supportedNFTContractsMap[nftContract];
    }

    /**
     * @dev Function to get the index of a supported NFT contract.
     * @param nftContract Address of the NFT contract.
     * @return Index of the NFT contract in the `supportedNFTContracts` array.
     */
    function getNFTContractIndex(address nftContract) internal view returns (uint256) {
        require(isNFTContractSupported(nftContract), "NFT contract not found");

        for (uint256 i = 0; i < supportedNFTContracts.length; i++) {
            if (address(supportedNFTContracts[i]) == nftContract) {
                return i;
            }
        }

        revert("NFT contract not found"); // Add revert statement if the contract is not found
    }

    /**
     * @dev Function to get the addresses of the supported NFT contracts.
     * @return Array of supported NFT contract addresses.
     */
    function getSupportedNFTContracts() external view returns (address[] memory) {
        address[] memory contracts = new address[](supportedNFTContracts.length);
        for (uint256 i = 0; i < supportedNFTContracts.length; i++) {
            contracts[i] = address(supportedNFTContracts[i]);
        }
        return contracts;
    }

    /**
     * @dev Function to create a new listing for an NFT.
     * @param tokenId ID of the NFT.
     * @param price Price of the NFT.
     * @param nftContract Address of the NFT contract.
     */
    function createListing(uint256 tokenId, uint256 price, address nftContract) external onlyNFTOwner(tokenId, nftContract) {
        require(price > 0, "Price must be greater than 0");

        // Calculate the listing fee
        uint256 listingFee = listingPrice;
        uint256 totalAmount = price + listingFee;

        // Transfer the NFT to the marketplace
        ERC721Enumerable(nftContract).transferFrom(msg.sender, address(this), tokenId);

        // Create the listing
        listings[tokenId] = Listing({
            seller: payable(msg.sender),
            tokenId: tokenId,
            price: totalAmount, // Include the listing fee
            nftContract: nftContract,
            active: true
        });

        emit ListingCreated(msg.sender, tokenId, totalAmount, nftContract, listingFee);
    }

    /**
     * @dev Function to remove a listing by the seller.
     * @param tokenId ID of the NFT.
     * @param nftContract Address of the NFT contract.
     */
    function removeListing(uint256 tokenId, address nftContract) external whenNotPaused onlySeller(tokenId, nftContract) listingExists(tokenId, nftContract) {
        // Transfer the NFT back to the seller
        ERC721Enumerable(nftContract).transferFrom(address(this), msg.sender, tokenId);

        // Remove the listing
        Listing storage listing = listings[tokenId];
        uint256 price = listing.price;
        delete listings[tokenId];

        emit ListingRemoved(tokenId, nftContract, price);
    }

    /**
     * @dev Function to remove a listing by the contract owner.
     * @param tokenId ID of the NFT.
     * @param nftContract Address of the NFT contract.
     */
    function removeListingByOwner(uint256 tokenId, address nftContract) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) listingExists(tokenId, nftContract) {
        // Transfer the NFT back to the seller
        ERC721Enumerable(nftContract).transferFrom(address(this), listings[tokenId].seller, tokenId);

        // Remove the listing
        Listing storage listing = listings[tokenId];
        uint256 price = listing.price;
        delete listings[tokenId];

        emit ListingRemoved(tokenId, nftContract, price);
    }

    /**
     * @dev Function to buy a listing.
     * @param tokenId ID of the NFT.
     * @param nftContract Address of the NFT contract.
     */
    function buyListing(uint256 tokenId, address nftContract) external whenNotPaused payable listingExists(tokenId, nftContract) {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Listing is no longer active");
        require(msg.value == listing.price, "Incorrect payment amount");

        // Calculate and send the commission to the contract owner
        uint256 commissionAmount = (listing.price * commissionRate) / 100;
        payable(owner()).transfer(commissionAmount);

        // Transfer the remaining amount to the seller
        listing.seller.transfer(listing.price - commissionAmount);

        // Transfer the NFT to the buyer
        ERC721Enumerable(nftContract).transferFrom(address(this), msg.sender, tokenId);

        // Deactivate the listing
        listing.active = false;
        delete listings[tokenId];

        emit ListingRemoved(tokenId, nftContract, listing.price);
        emit ListingPurchased(msg.sender, tokenId, nftContract, listing.price, commissionAmount);
    }

    /**
     * @dev Function to set the listing price.
     * @param newPrice New listing price.
     */
    function setListingPrice(uint256 newPrice) external onlyOwner {
        listingPrice = newPrice;
    }

    /**
     * @dev Function to set the commission rate.
     * @param newCommissionRate New commission rate.
     */
    function setCommissionRate(uint256 newCommissionRate) external onlyOwner {
        require(newCommissionRate <= 100, "Commission rate must be <= 100%");
        commissionRate = newCommissionRate;
    }

    /**
     * @dev Function to add a supported NFT contract.
     * @param nftContract Address of the NFT contract to be added.
     */
    function addSupportedNFTContract(address nftContract) public onlyRole(SUPPORT_ROLE) {
        require(!isNFTContractSupported(nftContract), "NFT contract is already supported");
        supportedNFTContracts.push(ERC721Enumerable(nftContract));
        supportedNFTContractsMap[nftContract] = true;
    }

    /**
     * @dev Function to remove a supported NFT contract.
     * @param nftContract Address of the NFT contract to be removed.
     */
    function removeSupportedNFTContract(address nftContract) external onlyRole(SUPPORT_ROLE) {
        uint256 index = getNFTContractIndex(nftContract);
        supportedNFTContractsMap[nftContract] = false;
        supportedNFTContracts[index] = supportedNFTContracts[supportedNFTContracts.length - 1];
        supportedNFTContracts.pop();
    }
}
