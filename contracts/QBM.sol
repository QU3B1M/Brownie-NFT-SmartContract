// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "./ProxyRegistry.sol";

contract QBM is ERC721A, Ownable, ReentrancyGuard {
     // Constants: General Configuration
    uint256 public constant MAX_SUPPLY = 555;
    uint256 public constant MAX_PER_USER = 5;
    uint256 public constant SUPPLY_FOR_DEVS = 50;
    // Constants: Prices.
    uint256 public constant START_PRICE = 1 ether;
    uint256 public constant END_PRICE = 0.04 ether;
    uint256 public constant WHITELIST_PRICE = 0.025 ether;
    // Constants: Auction Configuration.
    uint256 public constant AUCTION_DURATION = 240 minutes;
    uint256 public constant AUCTION_INTERVAL = 20 minutes;
    uint256 public constant AUCTION_DROP = (START_PRICE - END_PRICE) / (AUCTION_DURATION / AUCTION_INTERVAL);
    // Immutable Variables: Sales start time & Proxy Registry.
    address public immutable proxyRegistryAddress;
    uint256 public immutable auctionStartTime;
    uint256 public immutable whitelistSaleStartTime;
    // Variables: Next token ID, Base and Contracr URIs & Whitelist.
    string public baseURI = "";
    string private _contractURI = "";
    mapping(address => uint256) public whitelist;

    constructor(
        address _proxyRegistryAddress, 
        uint256 _whitelistSaleStartTime,
        uint256 _auctionStartTime
    ) ERC721A("QU3B1M", "QBM") {
        proxyRegistryAddress = _proxyRegistryAddress;
        whitelistSaleStartTime = _whitelistSaleStartTime;
        auctionStartTime = _auctionStartTime;
    }

    /// @notice Validate if the caller is a usar or another contract.
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "Quebim: The caller is another contract.");
        _;
    }

    /// @notice Whitelist mint, only callable by whitelisted user.
    function whitelistMint() external payable callerIsUser {
        require(msg.value >= WHITELIST_PRICE, "Quebim: Not enough ETH.");
        require(block.timestamp >= whitelistSaleStartTime,"Quebim: Whitelist sale has not started yet.");
        require(whitelist[msg.sender] > 0, "Quebim: User has no mints reserved.");
        require(balanceOf(msg.sender) < MAX_PER_USER, "Quebim: Exceeds the max amount per user.");
        
        whitelist[msg.sender]--; // Update the user remaining amount.
        _safeMint(msg.sender, 1);
        _refund(WHITELIST_PRICE);
    }

    /// @notice Dutch Auction mint, allows mint several Quebim paying reduced gas.
    /// Once the Auction is done this function keeps working as public mint selling at the end price.
    function auctionMint(uint256 amount) external payable callerIsUser {        
        uint256 _totalPrice = getAuctionPrice() * amount;

        require(msg.value >= _totalPrice,"Quebim: Not enough ETH.");
        require(block.timestamp >= auctionStartTime,"Quebim: Auction has not started yet.");
        require(_totalMinted() + amount <= MAX_SUPPLY, "Quebim: Exceeds the max supply.");
        require(balanceOf(msg.sender) + amount <= MAX_PER_USER, "Quebim: Exceeds the max amount per user.");

        _safeMint(msg.sender, amount);
        _refund(_totalPrice);
    }

    /// @notice Mint for Marketing/Prizes/Dev purposes.
    function devMint(address _to, uint256 amount) external onlyOwner {
        require(_totalMinted() + amount <= SUPPLY_FOR_DEVS, "Quebim: Exceeds the mints reserved for devs.");
        require(block.timestamp < whitelistSaleStartTime, "Quebim: Dev mint is over.");
        
        _safeMint(msg.sender, amount);
    }

    /// @notice Withdraw the funds, only callable by contract owner.
    function withdraw() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Quebim: Withdraw failed.");
    }

    /// @notice Register the seed whitelist, only callable by owner.
    function seedWhitelist(address[] calldata addresses, uint256[] calldata amounts) external onlyOwner {
        require(addresses.length > 0, "Quebim: Whitelist is empty.");
        require(addresses.length == amounts.length, "Quebim: Addresses do not match amounts.");
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = amounts[i];
        } 
    }

    /// @notice Base URI setter, only callable by contract owner.
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    /// @notice Contract URI setter, only callable by contract owner.
    function setContractURI(string memory newContractURI) external onlyOwner {
        _contractURI = newContractURI;
    }

    /// @notice Contract URI getter.
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /// @notice Retrieve the current DystoBear price in the auction.
    function getAuctionPrice() public view returns (uint256) {
        uint256 _saleStartTime = auctionStartTime;
        if (block.timestamp < _saleStartTime) {
            return START_PRICE;
        }
        if (block.timestamp - _saleStartTime >= AUCTION_DURATION) {
            return END_PRICE;
        } else {
            uint256 steps = (block.timestamp - _saleStartTime) /
                AUCTION_INTERVAL;
            return START_PRICE - (steps * AUCTION_DROP);
        }
    }

    /// @notice Override isApprovedForAll from ERC721 to enable gas-less listings on Opensea.
    function isApprovedForAll(address owner, address operator) public view override(ERC721A) returns (bool) {
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        /// @notice Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /// @notice Retrieves the remaining ETH (the change) to the buyer. 
    function _refund(uint256 price) internal {
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    /// @notice Retrieves the baseURI, this will be called from ERC721.
    function _baseURI() internal override view returns (string memory){
        return baseURI;
    }
}
