// SPDX-License-Identifier: MIT
// Written by: Rob Secord (https://twitter.com/robsecord)
// Co-founder @ Charged Particles - Visit: https://charged.fi
// Co-founder @ Taggr             - Visit: https://taggr.io
// Forked @ Antz0x0z aka @k1llaHertz from CEM Network

pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./ERC721i.sol";

contract ContractOnCEMNetwork is ERC721i, ReentrancyGuard {
    using Address for address payable;
    using Counters for Counters.Counter;

    /* ============================================================= */

    Counters.Counter private _listedItems;
    Counters.Counter private _tokenIds;

    mapping(string => bool) private _usedTokenURIs;
    mapping (uint256 => uint256) public tokenSupply;
    mapping(address => mapping(uint => uint)) private _ownedTokens;
    mapping(uint => uint) private _idToOwnedIndex;
    mapping(uint => uint) private _idToNftIndex;
    /* ============================================================= */

    /// @dev Some sales-related events
    event Purchase(
        address indexed newOwner,
        uint256 amount,
        uint256 lastTokenId
    );
    event Withdraw(address indexed receiver, uint256 amount);
    event PriceUpdate(uint256 newPrice);

    /// @dev Track number of tokens sold
    Counters.Counter internal _lastPurchasedTokenId;
    
    /// @dev ERC721 Base Token URI
    string internal _baseTokenURI;

    // Individual NFT Sale Price in ETH
    uint256 public _pricePer;

    /// @dev The Deployer of this contract is also the Owner and the Pre-Mint Receiver.
    constructor(
        string memory name,
        string memory symbol,
        string memory baseUri,
        uint256 maxSupply
    ) ERC721i(name, symbol, _msgSender(), maxSupply) {
        _baseTokenURI = baseUri;
        for (uint i = 1; i <= maxSupply; i++) {
            _listedItems.increment();
            _preMint();
            _usedTokenURIs[baseUri] = false;
        }
        // Since we pre-mint to "owner", allow this contract to transfer on behalf of "owner" for sales.
        _setApprovalForAll(_msgSender(), address(this), true);
    }

    /* ============================================================= */

    function getURI(uint256 _tokenid) public view returns (string memory) {
        return uri(_tokenid, _baseTokenURI);
    }

     /// @dev Provide a Base URI for Token Metadata (override defined in ERC721.sol)
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function listedItemsCount() public view returns (uint256) {
        return _listedItems.current();
    }

    function tokenURIExists(string memory tokenURI) public view returns (bool) {
        return _usedTokenURIs[tokenURI] == true;
    }

    function tokenOfOwnerByIndex(address owner, uint index) public view override returns (uint) {
        require(index < ERC721.balanceOf(owner), "Index out of bounds");
        return _ownedTokens[owner][index];
    }

    /* ============================================================= */

    //in the function below include the CID of the JSON folder on IPFS

    /// @dev Let's Pre-Mint a Gazillion NFTs!!  (wait, 2^^256-1 equals what again?)
    function preMint() external onlyOwner {
        _preMint();
    }

    /**
     * @dev Purchases from the Pre-Mint Receiver are a simple matter of transferring the token.
     * For this reason, we can provide a very simple "batch" transfer mechanism in order to
     * save even more gas for our users.
     */
    function purchase(uint256 amount)
        external
        payable
        virtual
        nonReentrant
        returns (uint256 amountTransferred)
    {
        uint256 index = _lastPurchasedTokenId.current();
        if (index + amount > _maxSupply) {
            amount = _maxSupply - index;
        }

        uint256 cost;
        if (_pricePer > 0) {
            cost = _pricePer * amount;
            require(msg.value >= cost, "Insufficient payment");
        }

        uint256[] memory tokenIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            _lastPurchasedTokenId.increment();
            tokenIds[i] = _lastPurchasedTokenId.current();
        }
        amountTransferred = _batchTransfer(owner(), _msgSender(), tokenIds);

        emit Purchase(_msgSender(), amount, _lastPurchasedTokenId.current());

        // Refund overspend
        if (msg.value > cost) {
            payable(_msgSender()).sendValue(msg.value - cost);
        }
    }

    /// @dev Set the price for sales to maintain a purchase price of $1 USD
    function setPrice(uint256 newPrice) external onlyOwner {
        _pricePer = newPrice;
        emit PriceUpdate(newPrice);
    }

    /// @dev Withdraw ETH from Sales
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        address payable receiver = payable(owner());
        receiver.sendValue(amount);
        emit Withdraw(receiver, amount);
    }

    /// @dev Provide a Base URI for Token Metadata
    function uri(uint256 _tokenid, string memory _uri)
        private
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "ipfs://",
                    _uri,
                    "/",
                    Strings.toString(_tokenid),
                    ".json"
                )
            );
    }



    //
    // Batch Transfers
    //

    function batchTransfer(address to, uint256[] memory tokenIds)
        external
        virtual
        returns (uint256 amountTransferred)
    {
        amountTransferred = _batchTransfer(_msgSender(), to, tokenIds);
    }

    function batchTransferFrom(
        address from,
        address to,
        uint256[] memory tokenIds
    ) external virtual returns (uint256 amountTransferred) {
        amountTransferred = _batchTransfer(from, to, tokenIds);
    }

    function _batchTransfer(
        address from,
        address to,
        uint256[] memory tokenIds
    ) internal virtual returns (uint256 amountTransferred) {
        uint256 count = tokenIds.length;

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = tokenIds[i];

            // Skip invalid tokens; no need to cancel the whole tx for 1 failure
            // These are the exact same "require" checks performed in ERC721.sol for standard transfers.
            if (
                (ownerOf(tokenId) != from) ||
                (!_isApprovedOrOwner(from, tokenId)) ||
                (to == address(0))
            ) {
                continue;
            }

            _beforeTokenTransfer(from, to, tokenId);

            // Clear approvals from the previous owner
            _approve(address(0), tokenId);

            amountTransferred += 1;
            _owners[tokenId] = to;

            emit Transfer(from, to, tokenId);

            _afterTokenTransfer(from, to, tokenId);
        }

        // We can save a bit of gas here by updating these state-vars atthe end
        _balances[from] -= amountTransferred;
        _balances[to] += amountTransferred;
    }
}
