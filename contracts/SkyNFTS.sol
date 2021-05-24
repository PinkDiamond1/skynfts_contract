// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


import 'openzeppelin-solidity/contracts/access/Ownable.sol';
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

contract SkyNFTS is ERC721, Ownable {
    mapping (uint => uint) public price;
    mapping (uint => bool) public listedTokens;
    mapping (uint => address) public tokenCreator;

    event Minted(address indexed owner, uint256 tokenId, string tokenURI, uint price);
    event Purchased(address indexed previousOwner, address indexed newOwner, uint price, uint tokenId, string uri);
    // event PriceUpdate(address indexed owner, uint oldPrice, uint newPrice, uint tokenId);
    event NftListStatus(address indexed owner, uint tokenId, bool isListed, uint oldPrice, uint newPrice);

    constructor() ERC721("Sky NFToken", "SNFTS") public {

    }

    /**
    * @dev Internal function to set the token URI for a given token
    * Reverts if the token ID does not exist
    * @param _tokenId uint256 ID of the token to set its URI
    * @param _creator original token creator
    */
    function _setTokenCreator(uint256 _tokenId, address _creator) internal {
        require(_exists(_tokenId));
        tokenCreator[_tokenId] = _creator;
    }

    /**
     * @dev Public function to mint new token, assigns uri to token, sets sender as creator
     */
    function mint(string memory _tokenURI, uint _price) public returns (uint) {
        uint _tokenId = totalSupply() + 1;

        _mint(msg.sender, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
        _setTokenCreator(_tokenId, msg.sender);

        //Autolist token
        listedTokens[_tokenId] = true;
        price[_tokenId] = _price;

        emit Minted(msg.sender, _tokenId, _tokenURI, _price);

        return _tokenId;
    }



    function buy(uint _tokenId) external payable {
        _validate(_tokenId);

        address _currentOwner = ownerOf(_tokenId);
        address _newOwner = msg.sender;

        _trade(_tokenId);

        emit Purchased(_currentOwner, _newOwner, price[_tokenId], _tokenId, tokenURI(_tokenId));
    }

    function _validate(uint _tokenId) internal {
        bool isItemListed = listedTokens[_tokenId];
        require(_exists(_tokenId), "Error, token not exists");
        require(isItemListed, "Error, token not listed");
        require(msg.value >= price[_tokenId], "Error, price not matched");
        require(msg.sender != ownerOf(_tokenId), "Error, you already own this token");
    }

    function _trade(uint _tokenId) internal {
        address payable _buyer = payable(msg.sender);
        address payable _tokenOwner = payable(ownerOf(_tokenId));
        address payable _creator = payable(tokenCreator[_tokenId]);
        address payable _contractOwner = payable(owner());

        _transfer(_tokenOwner, _buyer, _tokenId);

        // 10% commission, 2,5% for market, 7,5% for creator
        uint _price = price[_tokenId];

        uint _marketCommision = SafeMath.div(_price, 40);
        uint _creatorCommision =  SafeMath.div(SafeMath.mul(_price, 3), 40);
        uint _sellerValue = _price - _marketCommision - _creatorCommision;

        _tokenOwner.transfer(_sellerValue);
        _contractOwner.transfer(_marketCommision);
        _creator.transfer(_creatorCommision);

        // If buyer sent more than price, we send them back their rest of funds
        if (msg.value > _price) {
            _buyer.transfer(msg.value - _price);
        }

        listedTokens[_tokenId] = false;
    }

    // function updatePrice(uint _tokenId, uint _price) public returns (bool) {
    //     uint oldPrice = price[_tokenId];
    //     require(msg.sender == ownerOf(_tokenId), "Error, you are not the owner");
    //     price[_tokenId] = _price;

    //     emit PriceUpdate(msg.sender, oldPrice, _price, _tokenId);
    //     return true;
    // }

    function updateListingStatus(uint _tokenId, bool _shouldBeListed, uint _price) public returns (bool) {
        require(msg.sender == ownerOf(_tokenId), "Error, you are not the owner");

        uint _oldPrice = price[_tokenId];

        listedTokens[_tokenId] = _shouldBeListed;
        price[_tokenId] = _price;

        emit NftListStatus(msg.sender, _tokenId, _shouldBeListed, _oldPrice, _price);

        return true;
    }
}