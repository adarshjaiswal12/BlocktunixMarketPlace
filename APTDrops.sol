// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "./APT721.sol";

import "./APT1155.sol";

import "./APTdrops.sol";

contract CommonMarket {
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

    struct RoyaltyInfo {
        uint256 tokenId;
        uint256 Type;
        address creator;
        uint256 royaltyPercentage;
    }

    struct BiddingDetails {
        address bidder;
        uint256 bidAmount;
        uint256 royaltyBidShare;
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

    BiddingDetails[] public _bidArray;

    //mapping tokenUri with bidder details struct
    mapping(string => BiddingDetails[]) public _biddingDetails;
    mapping(string => mapping(address => uint256)) private _indexDetails;
    mapping(string => bool ) private _onDrop;
    mapping(uint => DropsDetails) public dropInfo ;
    mapping(string => uint ) private _dropToId;

 //************only owner pending**************************

    APT721 private _erc721;
    APT1155 private _erc1155;
    APTDrops private _drop;
    address private _admin;
    uint dropId;
    // address private _pendingAdmin;
    uint256 public tokenId721 = 0;
    uint256 public tokenId1155 = 0;

    //do it private
    mapping(string => RoyaltyInfo) private royaltyDeatils;

    mapping(string => mapping(address => AssetDetails)) private _reSaleAssetId;

    // mapping(string => mapping(address => uint256)) private _indexDetails;

    mapping(address => uint256) public _addressAccumlatedAmount;

    event BoughtNFT(uint256 tokenId, address buyer);

    constructor(APT721 erc721, APT1155 erc1155) {
        
        //chechking address zero
        require(erc721 != APT721(address(0)), "APT_Market:zero address sent");
        require(erc1155 != APT1155(address(0)), "APT_Market:zero address sent");
        //setting admin to message sender
        _admin = msg.sender;
        _erc721 = erc721;
        _erc1155 = erc1155;
        //setting the market place address in the ERC721 and ERC1155 contract
        _erc721.setMarketAddress();
        _erc1155.setMarketAddress();
    
    }

    function setOnDrop (string[] memory uri , uint quantity , uint startTime ,uint endTime, uint perNftPrice ) external {
        
        require(startTime>block.timestamp," Starting time should be grater than current time ");
        require(endTime>startTime," Starting time grater than ending time ");
        require(quantity>0, " Quantity should be greter than 0 ");

        DropsDetails memory newAsset;
        dropId++;

        for (uint256 i =0 ; i < uri.length; i++){
        require(royaltyDeatils[uri[i]].tokenId == 0,"APT_Market: Token uri already exists");
        }

        for (uint256 i =0 ; i < uri.length; i++){
        _onDrop[uri[i]]=true;
        _dropToId[uri[i]]= dropId;
        }
        newAsset.onDrop=true ;
        newAsset.startingTime=startTime;
        newAsset.endTime=endTime;
        newAsset.totalQuantity = quantity;
        newAsset.remainingQuantity= quantity;
        newAsset.perNftPrice=perNftPrice;
        newAsset.owner= msg.sender;
        dropInfo[dropId]= newAsset;
    }

    function setOnBidding(
        string memory tokenUri,
        uint256 price,
        uint256 quantity
    ) external {
        RoyaltyInfo memory royaltyInfo = royaltyDeatils[tokenUri];
        // uint tokenId=royaltyInfo.tokenId;
        AssetDetails memory asset = _reSaleAssetId[tokenUri][msg.sender];

        require(asset.quantityOnSale == 0, "please remove asset from sale");
        require(price > 0, "Market Bid:please set a valid price");

        require(
            asset.tokenType == 721 || asset.tokenType == 1155,
            "Market sale:invalid token URI"
        );
        require(
            asset.quantityOnBidding == 0,
            "Market sale:sale created alredy "
        );

        require(
            quantity <= asset.remainingQuantity,
            "Market sale:No enough tokens left for bid"
        );

        asset.quantityOnBidding += quantity;
        asset.remainingQuantity -= quantity;
        asset.biddingPrice = price;
        if (royaltyInfo.creator != msg.sender) {
            asset.bidRoyalty = true;
        }
        _reSaleAssetId[tokenUri][msg.sender] = asset;

      
    }

    function removeFromBidding(string memory tokenUri) external {
        AssetDetails memory Asset = _reSaleAssetId[tokenUri][msg.sender];

        require(
            Asset.tokenType == 721 || Asset.tokenType == 1155,
            "invalid token URI"
        );

        require(Asset.quantityOnBidding != 0, "Remove Bid:No Bid found");

        uint256 arrayLength = _biddingDetails[tokenUri].length;
        
        if(arrayLength!=0){
          for (
                uint256 x = 0;
                x <= arrayLength - 1;
                x++
            ){
                    updateBiddingAmount(tokenUri, x, msg.sender);
                   
            }
            delete _biddingDetails[tokenUri];
        }

        Asset.remainingQuantity += Asset.quantityOnBidding;
        Asset.quantityOnBidding = 0;
        Asset.biddingPrice = 0;
        Asset.royaltySaleShare = 0;
        _reSaleAssetId[tokenUri][msg.sender] = Asset;
    }



    function bidAsset(address owner, string memory tokenUri) external payable {

        require(msg.value != 0, "please send some amount");
        require(msg.sender != owner, "Buy:You can't bid on your own nft");
        
        RoyaltyInfo memory royaltyInfo = royaltyDeatils[tokenUri];
        
        address creator = royaltyInfo.creator;
        
        AssetDetails memory Asset = _reSaleAssetId[tokenUri][owner];

        uint royaltyPercentage = royaltyInfo.royaltyPercentage;
        
        require(
            Asset.tokenType == 721 || Asset.tokenType == 1155,
            "invalid token ID"
        );
        require(
            creator != msg.sender,
            "Market Bid:creator bid not allowed"
        );
        require(Asset.tokenType != 0, "invalid token URI");
        
        uint256 biddingQuantity = Asset.quantityOnBidding;
        
        require(
            biddingQuantity != 0, 
            "This token has not listed for bidding"
        );

        require(
            Asset.biddingPrice < msg.value,
            "plz send amount above the min bidding price"
        );
    

        uint256 indexValue = _indexDetails[tokenUri][msg.sender];

        if (indexValue != 0) {
            BiddingDetails memory bidder=_biddingDetails[tokenUri][indexValue];
        

            _addressAccumlatedAmount[msg.sender] += bidder.bidAmount;

            bidder.bidAmount= msg.value ;

            if ( Asset.bidRoyalty==true ){
                bidder.royaltyBidShare= msg.value*royaltyPercentage/100;
            }
            _biddingDetails[tokenUri][indexValue]=bidder;


        }else{

            if ( Asset.bidRoyalty==true ){
                //pushing array
            
            _biddingDetails[tokenUri].push(BiddingDetails( msg.sender, msg.value, msg.value*royaltyPercentage/100 ));
            
            }
            else{
            
                _biddingDetails[tokenUri].push(BiddingDetails( msg.sender, msg.value , 0 ));
            
            }

        _indexDetails[tokenUri][msg.sender] =
            (_biddingDetails[tokenUri].length)-1 ;
    
        }
    }
   

    function withdrawbid( string memory  tokenUri) external {
       
        uint256 bidderIndex = _indexDetails[tokenUri][msg.sender];
       
        // require(bidderIndex);

        require(
            _biddingDetails[tokenUri][bidderIndex].bidder != address(0),
            "invalid bidder"
        );
       
        // require(_indexDetails[tokenUri][msg.sender] != 0, "invalid bidder");
       
        address bidder = msg.sender;
        
        removeBid(tokenUri, bidder, bidderIndex);
    }

    function rejectBid(
         string memory  tokenUri,
        address bidder
    ) external {
        
         AssetDetails memory Asset = _reSaleAssetId[tokenUri][msg.sender];

         RoyaltyInfo memory royaltyInfo = royaltyDeatils[tokenUri];


        onlyOwner(Asset.tokenType, royaltyInfo.tokenId, msg.sender);

        require(_indexDetails[tokenUri][bidder] >= 0, "invalid bidder");

        uint256 bidderIndex = _indexDetails[tokenUri][bidder];

        require(
            _biddingDetails[tokenUri][bidderIndex].bidder != address(0),
            "invalid bidder"
        );

        removeBid(tokenUri, bidder, bidderIndex);
    }
    
    function removeBid(
        string memory tokenUri,
        address bidder,
        uint256 bidderIndex
    ) private {

        BiddingDetails memory _bidder=_biddingDetails[tokenUri][bidderIndex];
        
        _addressAccumlatedAmount[bidder] += _bidder.bidAmount;
        
        _bidder.bidAmount=0;
        _bidder.royaltyBidShare=0;
        _biddingDetails[tokenUri][bidderIndex]=_bidder;

        // delete _biddingDetails[tokenUri][bidderIndex];
        
        // delete _indexDetails[tokenUri][bidder];
    }

    function bidArrayLength(string memory tokenUri) external view returns (uint){
          BiddingDetails[] memory bidArray = _biddingDetails[tokenUri];
          return bidArray.length;
    }

    function acceptBid(
        string memory tokenUri,
        address payable  _bidder
    ) external {
        // address creator = royaltyInfo.creator;
        
        AssetDetails memory Asset = _reSaleAssetId[tokenUri][msg.sender];

        BiddingDetails[] memory bidArray = _biddingDetails[tokenUri];

        require(Asset.tokenType == 721 || Asset.tokenType == 1155, "invalid token type");
    
        RoyaltyInfo memory royaltyInfo = royaltyDeatils[tokenUri];


        uint256 arrayLength = bidArray.length;

        if ( Asset.tokenType == 721 ) {
            require(
                _erc721.isApprovedForAll(msg.sender, address(this)),
                "contrat not approved to sell nft"
            );

            for (
                uint256 bidderArrayIndex = 0;
                bidderArrayIndex <= arrayLength - 1;
                bidderArrayIndex++
            ) {
                if (
                    bidArray[bidderArrayIndex].bidder == _bidder
                ) {

                    _addressAccumlatedAmount[msg.sender] += bidArray[bidderArrayIndex].bidAmount - 
                                    bidArray[bidderArrayIndex].royaltyBidShare;
                      
                    _addressAccumlatedAmount[royaltyInfo.creator]=bidArray[bidderArrayIndex].royaltyBidShare;

                        _sendERC721(_erc721.ownerOf(royaltyInfo.tokenId), _bidder, royaltyInfo.tokenId);
                    updateUser(tokenUri, 721, 1, _bidder);
                    quantityCheck(tokenUri, msg.sender);
                    // emit BoughtNFT(tokenId, msg.sender);
                }
             else {
                     _addressAccumlatedAmount[_biddingDetails[tokenUri][bidderArrayIndex].bidder] +=
                      _biddingDetails[tokenUri][bidderArrayIndex].bidAmount;
                }
            }
        } else if (Asset.tokenType == 1155) {
            require(
                _erc1155.isApprovedForAll(msg.sender, address(this)),
                "contract not approved to sell nft"
            );

            for (
                uint256 bidderArrayIndex = 0;
                bidderArrayIndex <= arrayLength -1 ;
                bidderArrayIndex++
            ) {
                if (
                    bidArray[bidderArrayIndex].bidder != _bidder
                ) 
                {
                     _addressAccumlatedAmount[bidArray[bidderArrayIndex].bidder] +=
                     bidArray[bidderArrayIndex].bidAmount;   
                }
                 else  {

                    _addressAccumlatedAmount[ msg.sender ] += bidArray[bidderArrayIndex].bidAmount -
                        bidArray[bidderArrayIndex].royaltyBidShare;

                    _addressAccumlatedAmount[royaltyInfo.creator]+=bidArray[bidderArrayIndex].royaltyBidShare;

                    _sendERC1155( msg.sender, _bidder , royaltyInfo.tokenId , Asset.quantityOnBidding );
                    updateUser(tokenUri, 1155, Asset.quantityOnBidding , _bidder);
                    quantityCheck(tokenUri, msg.sender);
                }
            }
            // delete _biddingDetails[tokenUri];
        }
    }


//adding money to the bidder and do removing  array
     function updateBiddingAmount(
        string memory tokenUri,
        uint256 bidderArrayIndex,
        address  bidder
    ) private {
        
        _addressAccumlatedAmount[bidder] +=
        _biddingDetails[tokenUri][bidderArrayIndex].bidAmount;
        delete _indexDetails[tokenUri][bidder];
    }

    
    function onlyOwner(
        uint256 tokenType,
        uint256 tokenId,
        address owner
    ) private view {
        if (tokenType == 721) {
            require(_erc721.ownerOf(tokenId) == owner, "invalid owner");
        } else if (tokenType == 1155) {
            require(
                _erc1155.balanceOf(owner, tokenId) != 0,
                "wrong owner, token type or token id"
            );
        }
    }


    function quantityCheck(
        string memory tokenUri,
        address checkAddress
    ) private {

         AssetDetails memory reSaleAsset = _reSaleAssetId[tokenUri][checkAddress];

        if (
            reSaleAsset.remainingQuantity + reSaleAsset.quantityOnBidding == 0
        ) {
            delete _reSaleAssetId[tokenUri][checkAddress];
        } else {
            reSaleAsset.quantityOnBidding = 0;
            reSaleAsset.biddingPrice = 0;
            reSaleAsset.royaltySaleShare = 0;
            _reSaleAssetId[tokenUri][checkAddress] = reSaleAsset;
        }
        delete _biddingDetails[tokenUri];
    }

    
 
    function getAsset(
        string memory tokenUri,
        address owner
    ) external view returns (AssetDetails memory asset) {
        return _reSaleAssetId[tokenUri][owner];
    }

    function getRoyalty(
        string memory tokenUri
    ) external view returns (RoyaltyInfo memory royalty) {
        return royaltyDeatils[tokenUri];
    }

    function mintUser (
        string memory tokenUri,
        uint256 quantity,
        uint256 royaltiesPercentage
    ) external payable {
        require(quantity > 0, "APT_Market:Invalid quantity");
        bool OnDrop = _onDrop[tokenUri];
        
        uint id=_dropToId[tokenUri];

        if (OnDrop==true){
            require( dropInfo[id].remainingQuantity>= quantity , "All drop nfts minted" );
            require( dropInfo[id].endTime > block.timestamp , "Drop time ended " );
            require( dropInfo[id].perNftPrice*quantity == msg.value , "Invalid price sent for the drop mint" );
        }else{
        require(
            royaltyDeatils[tokenUri].tokenId == 0,
            "APT_Market: Token uri already exists"
        );
            }
        require(royaltiesPercentage >= 0, "please enter valid percentage");
        AssetDetails memory newAsset;
        if(_reSaleAssetId[tokenUri][msg.sender].remainingQuantity!=0){
           newAsset=_reSaleAssetId[tokenUri][msg.sender];
        }
        // AssetDetails memory newAsset;
        RoyaltyInfo memory newRoyalty;

        if (quantity == 1 && OnDrop==false ) {

            tokenId721++;
            _erc721.mint(msg.sender, tokenUri, tokenId721);
            newAsset.tokenType = 721;
            newAsset.url = tokenUri;
            newAsset.remainingQuantity = quantity;
            _reSaleAssetId[tokenUri][msg.sender] = newAsset;
            newRoyalty.Type += 721;
            newRoyalty.tokenId = tokenId721;
        
        } else {  

            tokenId1155++;
            _erc1155.mint(msg.sender, quantity, tokenUri, tokenId1155);
            newAsset.tokenType = 1155;
            newAsset.url = tokenUri;
            newAsset.remainingQuantity += quantity;
            _reSaleAssetId[tokenUri][msg.sender] = newAsset;
            newRoyalty.Type = 1155;
            newRoyalty.tokenId = tokenId1155;

        }

        newRoyalty.creator = msg.sender;
        newRoyalty.royaltyPercentage = royaltiesPercentage;
        royaltyDeatils[tokenUri] = newRoyalty;
        if (OnDrop){
            _addressAccumlatedAmount[dropInfo[id].owner] += msg.value;
            dropInfo[id].remainingQuantity =  dropInfo[id].remainingQuantity - quantity ;
        }

    }

    function isOnDrop(string memory tokenUri) external view returns(bool){
        return _onDrop[tokenUri];
    } 

    function setOnSale(
        string memory tokenUri,
        uint256 price,
        uint256 quantity
    ) external {
        RoyaltyInfo memory royaltyInfo = royaltyDeatils[tokenUri];
        // uint tokenId=royaltyInfo.tokenId;
        AssetDetails memory asset = _reSaleAssetId[tokenUri][msg.sender];

        require(price > 0, "Market sale:please set a valid price");

        require(
            asset.tokenType == 721 || asset.tokenType == 1155,
            "Market sale:invalid token URI"
        );

        require(asset.quantityOnSale == 0, "Market sale:sale created alredy ");
        require(
            quantity <= asset.remainingQuantity,
            "Market sale:No enough tokens left for sale"
        );

        asset.quantityOnSale += quantity;
        asset.remainingQuantity -= quantity;
        asset.salePrice = price;   
        if (royaltyInfo.creator != msg.sender) {
            asset.royaltySaleShare = ((price *
                royaltyDeatils[tokenUri].royaltyPercentage) / 100);
        }
        _reSaleAssetId[tokenUri][msg.sender] = asset;
    }

    function removeFromSale(string memory tokenUri) external {
        AssetDetails memory Asset = _reSaleAssetId[tokenUri][msg.sender];

        require(
            Asset.tokenType == 721 || Asset.tokenType == 1155,
            "invalid token URI"
        );

        require(Asset.quantityOnSale != 0, "Remove Sale:No sale found");
        Asset.remainingQuantity += Asset.quantityOnSale;
        Asset.quantityOnSale = 0;
        Asset.salePrice = 0;
        Asset.royaltySaleShare = 0;
        _reSaleAssetId[tokenUri][msg.sender] = Asset;
    }

    function updateUser(
        string memory uri,
        uint _type,
        uint quantity,
        address account
    ) internal {
        AssetDetails memory newAsset = _reSaleAssetId[uri][account];
        newAsset.url = uri;
        newAsset.tokenType = _type;
        newAsset.remainingQuantity += quantity;
        _reSaleAssetId[uri][account] = newAsset;
    }



    //reentracy attack proof
    function buyImage(address owner, string memory tokenUri) external payable {
        require(msg.sender != owner, "Buy:You can't buy your own nft");
        RoyaltyInfo memory royaltyInfo = royaltyDeatils[tokenUri];
        uint tokenId = royaltyInfo.tokenId;
        address creator = royaltyInfo.creator;
        AssetDetails memory Asset = _reSaleAssetId[tokenUri][owner];

        require(
            Asset.tokenType == 721 || Asset.tokenType == 1155,
            "invalid token ID"
        );

        require(
            creator != msg.sender,
            "Market Buy:creator buyback not allowed"
        );
        require(Asset.tokenType != 0, "invalid token URI");

        if (Asset.tokenType == 721) {
            uint256 saleQuantity = Asset.quantityOnSale;
            require(
                saleQuantity != 0,
                "This token has not been listed on sale"
            );
            require(
                msg.value == Asset.salePrice + Asset.royaltySaleShare,
                "please enter valid price to buy nft"
            );

            resaleUpdate(tokenUri, owner);
            _addressAccumlatedAmount[msg.sender] += Asset.salePrice;
            _addressAccumlatedAmount[creator] += Asset.royaltySaleShare;
            _sendERC721(owner, msg.sender, tokenId);

            updateUser(tokenUri, 721, 1, msg.sender);
        } else {
            require(
                Asset.quantityOnSale != 0,
                "This token has not been listed on sale"
            );
            require(
                msg.value == Asset.salePrice + Asset.royaltySaleShare,
                "please enter valid price to buy nft"
            );

            resaleUpdate(tokenUri, owner);

            _addressAccumlatedAmount[owner] += Asset.salePrice;
            _addressAccumlatedAmount[creator] += Asset.royaltySaleShare;

            _sendERC1155(owner, msg.sender, tokenId, Asset.quantityOnSale);

            updateUser(tokenUri, 1155, Asset.quantityOnSale, msg.sender);
        }
        emit BoughtNFT(tokenId, msg.sender);
    }

    function withdrawAccumlatedAmount(uint256 amount) external {
        require(amount > 0, "Please withdraw some amount");
        require(
            _addressAccumlatedAmount[msg.sender] >= amount,
            "Withdraw amount:you have entered wrong amount"
        );
        _addressAccumlatedAmount[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function resaleUpdate(string memory uri, address checkAddress) private {
        AssetDetails memory reSaleAsset = _reSaleAssetId[uri][checkAddress];

        if (
            reSaleAsset.remainingQuantity + reSaleAsset.quantityOnBidding == 0
        ) {
            delete _reSaleAssetId[uri][checkAddress];
        } else {
            reSaleAsset.quantityOnSale = 0;
            reSaleAsset.salePrice = 0;
            reSaleAsset.royaltySaleShare = 0;
            _reSaleAssetId[uri][checkAddress] = reSaleAsset;
        }
    }

    function _sendERC721(address owner, address to, uint256 tokenId) private {
        _erc721.safeTransferFrom(owner, to, tokenId);
    }

    function _sendERC1155(
        address owner,
        address to,
        uint256 tokenId,
        uint256 quantity
    ) private {
        _erc1155.safeTransferFrom(owner, to, tokenId, quantity, "");
    }

    function updateRemainingQuantity(string memory uri, address owner , uint amount,uint action) public{
        if(action == 1){
         _reSaleAssetId[uri][owner].remainingQuantity += amount;
        }else if (action == 2 ){
        _reSaleAssetId[uri][owner].remainingQuantity -= amount;
        }
    }
}
