// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "./APT20.sol";

import "./APT721.sol";

import "./APT1155.sol";

import "./APTMarket.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract APTDrops {

    struct AssetDetails {
        uint256 tokenType;
        string url;
        uint256 biddingPrice;
        uint256 salePrice;
        uint256 royaltySaleShare;
        bool bidRoyalty;
        uint256 quantityOnSale;
        uint256 quantityOnBidding;
        uint256 remainingQuantity;
    }

    struct DropsDetails  {
        bool onDrop;
        uint256 startingTime;
        uint256 endTime;
        uint256 totalQuantity;
        uint256 remainingQuantity;
        uint perNftPrice;
        address owner;
    }

    APT721 private _erc721;
    APT1155 private _erc1155;
    CommonMarket private _market;
    uint dropId;
   

    mapping(string => bool ) private _onDrop;
    mapping(address => uint256) public _addressAccumlatedAmount;
    mapping(uint => DropsDetails) private dropInfo ;
    mapping(string => uint ) private _dropToId;


    constructor(APT721 erc721, APT1155 erc1155 ,CommonMarket market) {
        //chechking address zero
        require(erc721 != APT721(address(0)), "APT_Market:zero address sent");
        require(erc1155 != APT1155(address(0)), "APT_Market:zero address sent");
        //setting admin to message sender
        
        _erc721 = erc721;
        _erc1155 = erc1155;
        _market = market;
        // _market.getAsset(tokenUri, owner).url,
            // _market.getAsset(tokenUri, owner).biddingPrice,
            // _market.getAsset(tokenUri, owner).salePrice,
            // _market.getAsset(tokenUri, owner).royaltySaleShare,
            // _market.getAsset(tokenUri, owner).bidRoyalty,
            // _market.getAsset(tokenUri, owner).quantityOnSale,
            // _market.getAsset(tokenUri, owner).quantityOnBidding,
            // _market.getAsset(tokenUri, owner).remainingQuantity);
        // _reward = reward;
        // _reward.setSatkingAddress();
    }

    function onDrop(string memory uri) external view returns(bool){
        return _onDrop[uri];
    }
     


    function setOnDrop (string[] memory uri , uint quantity , uint startTime ,uint endTime, uint perNftPrice ) external {
        
        require(startTime>block.timestamp," Starting time should be grater than current time ");
        require(endTime>startTime," Starting time grater than ending time ");
        require(quantity>0, " Quantity should be greter than 0 ");

        DropsDetails memory newAsset;
        dropId++;

        for (uint256 i =0 ; i < uri.length; i++){
        _onDrop[uri[i]]=true;
        _dropToId[uri[i]]= dropId;
        }

        newAsset.startingTime=startTime;
        newAsset.endTime=endTime;
        newAsset.totalQuantity = quantity;
        newAsset.perNftPrice=perNftPrice;
        newAsset.owner= msg.sender;
        dropInfo[dropId]= newAsset;

    }

   
    function checkQuantity(string memory uri) external view returns(uint){
        uint id=_dropToId[uri];
        return dropInfo[id].remainingQuantity;
    }
    
    function checkOwner ( string memory uri ) external view returns(address){
        uint id=_dropToId[uri];
        return dropInfo[id].owner;
    }

    function checkPrice(string memory uri) external view returns(uint){
        uint id=_dropToId[uri];
        return dropInfo[id].perNftPrice;
    }


    function checkTime(string memory uri) external view returns(uint){
        uint id=_dropToId[uri];
        return dropInfo[id].endTime;
    }



    
    }
