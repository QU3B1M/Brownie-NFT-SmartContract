// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "./ProxyRegistry.sol";

/// @author QU3B1M.
contract QBM is ERC721A, Ownable, ReentrancyGuard {
     // Constants: General Configuration
    uint256 public constant MAX_SUPPLY = 40;
    uint256 public constant MAX_PER_USER = 5;
    uint256 public constant SUPPLY_FOR_DEVS = 15;
    // Constants: Prices.
    uint256 public constant PUBLIC_PRICE = 0.069 ether;
    uint256 public constant WHITELIST_PRICE = 0.025 ether;
    // Immutable Variables: Sales start time & Proxy Registry.
    address public immutable proxyRegistryAddress;
    uint256 public immutable publicSaleStartTime;
    uint256 public immutable whitelistSaleStartTime;
    // Variables: Next token ID, Base and Contracr URIs & Whitelist.
    string private _baseTokenURI = "";
    string private _contractURI = "";
    mapping(address => uint256) public whitelist;

    constructor(
        address _proxyRegistryAddress, 
        uint256 _whitelistSaleStartTime,
        uint256 _publicSaleStartTime
    ) ERC721A("Quebim", "QBM") {
        proxyRegistryAddress = _proxyRegistryAddress;
        whitelistSaleStartTime = _whitelistSaleStartTime;
        publicSaleStartTime = _publicSaleStartTime;
    }

    /// @notice Validate if the caller is a usar or another contract.
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "QBM: The caller is another contract.");
        _;
    }

    /// @notice Whitelist mint, only callable by whitelisted user.
    function whitelistMint() external payable callerIsUser {
        require(block.timestamp >= whitelistSaleStartTime,"QBM: Whitelist sale has not started yet.");
        require(whitelist[msg.sender] > 0, "QBM: User has no mints reserved.");
        require(balanceOf(msg.sender) < MAX_PER_USER, "QBM: Exceeds the max amount per user.");
        require(_totalMinted() <= MAX_SUPPLY, "QBM: Exceeds the max supply.");
        require(msg.value >= WHITELIST_PRICE, "QBM: Not enough ETH.");
        
        whitelist[msg.sender]--; // Update the user remaining amount.
        _safeMint(msg.sender, 1);
        _refund(WHITELIST_PRICE);
    }
    
    /// @notice Public mint, allows mint several NFTs paying reduced gas.
    function publicMint(uint256 amount) external payable callerIsUser {        
        require(block.timestamp >= publicSaleStartTime,"QBM: Public sale has not started yet.");
        uint256 _totalPrice = PUBLIC_PRICE * amount;
        require(balanceOf(msg.sender) + amount <= MAX_PER_USER, "QBM: Exceeds the max amount per user.");
        require(msg.value >= _totalPrice,"QBM: Not enough ETH.");
        require(_totalMinted() + amount <= MAX_SUPPLY, "QBM: Exceeds the max supply.");

        _safeMint(msg.sender, amount);
        _refund(_totalPrice);
    }

    /// @notice Mint for Marketing/Prizes/Dev purposes.
    function devMint(address _to, uint256 amount) external onlyOwner {
        require(block.timestamp < whitelistSaleStartTime, "QBM: Dev mint is over.");
        require(_totalMinted() + amount <= SUPPLY_FOR_DEVS, "QBM: Exceeds the mints reserved for devs.");
        
        _safeMint(_to, amount);
    }

    /// @notice Withdraw the funds, only callable by contract owner.
    function withdraw() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "QBM: Withdraw failed.");
    }

    /// @notice Register the seed whitelist, only callable by owner.
    function registerWhitelist(address[] calldata accounts, uint256[] calldata amounts) external onlyOwner {
        require(accounts.length > 0, "QBM: No accounts provided.");
        require(accounts.length == amounts.length, "QBM: Amounts and accounts don't match.");
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = amounts[i];
        } 
    }

    /// @notice Base URI setter, only callable by contract owner.
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /// @notice Contract URI setter, only callable by contract owner.
    function setContractURI(string memory newContractURI) external onlyOwner {
        _contractURI = newContractURI;
    }

    /// @notice Contract URI getter.
    function contractURI() external view returns (string memory) {
        return _contractURI;
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

    /// @notice Set the first token ID as 1.
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Retrieves the baseURI, this will be called from ERC721A.
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
