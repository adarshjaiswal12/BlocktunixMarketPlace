// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "./APT20.sol";

import "./APT721.sol";

import "./APT1155.sol";

import "./APTMarket.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract NftStaking is ERC1155Holder {

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

    struct StakingDetails  {
        uint256 startingTime;
        uint256 lastPayoutTime;
        uint256 quantity;
    }

    APT721 private _erc721;
    APT1155 private _erc1155;
    CommonMarket private _market;
    RewardToken private _reward;

    mapping(string => mapping(address => StakingDetails)) private stakingInfo ;
        mapping(address => uint256) public _addressAccumlatedAmount;


    

    constructor(APT721 erc721, APT1155 erc1155 ,CommonMarket market, RewardToken reward) {
        //chechking address zero
        require(erc721 != APT721(address(0)), "APT_Market:zero address sent");
        require(erc1155 != APT1155(address(0)), "APT_Market:zero address sent");
        //setting admin to message sender
        
        _erc721 = erc721;
        _erc1155 = erc1155;
        _market = market;
        _reward = reward;
        _reward.setSatkingAddress();
    }

    function getAsset(string memory tokenUri, address owner) external view returns (AssetDetails memory ) {
                return AssetDetails(_market.getAsset(tokenUri, owner).tokenType,
            _market.getAsset(tokenUri, owner).url,
            _market.getAsset(tokenUri, owner).biddingPrice,
            _market.getAsset(tokenUri, owner).salePrice,
            _market.getAsset(tokenUri, owner).royaltySaleShare,
            _market.getAsset(tokenUri, owner).bidRoyalty,
            _market.getAsset(tokenUri, owner).quantityOnSale,
            _market.getAsset(tokenUri, owner).quantityOnBidding,
            _market.getAsset(tokenUri, owner).remainingQuantity);
    }


    function stakeNft(string memory tokenUri,  uint quantity)external{
        StakingDetails memory details=stakingInfo[tokenUri][msg.sender];
        require(details.quantity== 0 , "Please remove Already staked " );
        require(_market.getAsset(tokenUri, msg.sender).remainingQuantity>=quantity);
        uint tokenId=_market.getRoyalty(tokenUri).tokenId;
        if(_market.getAsset(tokenUri,msg.sender).tokenType==721){
            _erc721.safeTransferFrom(msg.sender,address(this),tokenId);
        }else{
            _erc1155.safeTransferFrom(msg.sender,address(this),tokenId,quantity,'');
        }
        _market.updateRemainingQuantity(tokenUri,msg.sender,quantity,2);
         StakingDetails memory newAsset;
        newAsset.startingTime=block.timestamp ;
        newAsset.quantity= quantity;
        stakingInfo[tokenUri][msg.sender] = newAsset;
    }

    // function withdrawStaking(string memory tokenUri)external{
    //     StakingDetails memory details=stakingInfo[tokenUri][msg.sender];
    //     require(details.quantity!=0, "Nothing found") ;

    //     if(block.timestamp-stakingInfo[tokenUri][msg.sender].time == 1 hour){

    //     } ;

    // }

    function unstakeNft(string memory tokenUri) external {
        StakingDetails memory details=stakingInfo[tokenUri][msg.sender];
          require(details.quantity!=0, "No staking found");
          require (block.timestamp - details.startingTime >= 3 minutes,"You can unstake after 3 minutes ");
        uint tokenType = _market.getAsset(tokenUri, msg.sender).tokenType;
          uint tokenId = _market.getRoyalty(tokenUri).tokenId;

          if(tokenType==721){
               _erc721.transferFrom(address(this),msg.sender,tokenId);
          }else{
               _erc1155.safeTransferFrom(address(this),msg.sender,tokenId,details.quantity,'');
          }
            _addressAccumlatedAmount[msg.sender]=500;
          delete stakingInfo[tokenUri][msg.sender];
          _market.updateRemainingQuantity(tokenUri,msg.sender,details.quantity,1);
        
    }

    // function checkRewards(string memory tokenUri, address owner ,uint permonthreward ) external {
    //     StakingDetails memory details=stakingInfo[tokenUri][msg.sender];
    //     require (block.timestamp - details.startingTime >= 3 minutes,"Rewards will be added only afer 3 minutes ");
    //     uint timeInMinutes=(block.timestamp - details.startingTime)/60;
    //     uint lastMonth=getMonth(details.lastWithdrawTime);
    //     uint recentMonth=getMonth(block.timestamp);
    //     if (recentMonth - lastMonth ==0){
    //         (getDay(block.timestamp)-getDay(details.lastWithdrawTime))*
    //         rewardsperday(permonthreward,getYear(block.timestamp),getMonth(block.timestamp));

    //     }else if(recentMonth - lastMonth == 1){

    //     }else if (recentMonth - lastMonth > 1 ){

    //     }
    // }

    function withdrawBalance()external{
        uint amount = _addressAccumlatedAmount[msg.sender];
        require(amount!=0,"no available balance");
        _addressAccumlatedAmount[msg.sender]=0;
        _reward.mint(msg.sender,amount);
    }
   


    function rewardsperday(uint permonthreward , uint year , uint month) public pure returns(uint){
       
        return permonthreward/getDaysInMonth(year, month) ;

    }
    

function getDaysInMonth(uint256 year, uint256 month) public pure returns (uint256) {
    require(month >= 1 && month <= 12, "Invalid month");
    if (month == 2) {
        if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
            return 29; // Leap year
        } else {
            return 28;
        }
    } else if (month == 4 || month == 6 || month == 9 || month == 11) {
        return 30;
    } else {
        return 31;
    }
}

function getCurrentMonthDays() public view returns (uint256) {
    uint256 year;
    uint256 month;
    uint256 day;
    (year, month, day) = getCurrentDate();
    return getDaysInMonth(year, month);
}

function getCurrentDate() public view returns (uint256 year, uint256 month, uint256 day) {
    uint256 timestamp = block.timestamp;
    year = getYear(timestamp);
    month = getMonth(timestamp);
    day = getDay(timestamp);
}

function getYear(uint256 timestamp) public pure returns (uint256) {
    uint256 secondsInYear = 31536000; // 365 days
    return ((timestamp / secondsInYear) + 1970);
}

function getMonth(uint256 timestamp) public pure returns (uint256) {
    uint256 year = getYear(timestamp);
    uint256 secondsInMonth = 2629746; // average number of seconds in a month
    uint256 elapsedSeconds = timestamp - getYearStartTimestamp(year);
    uint256 elapsedMonths = elapsedSeconds / secondsInMonth;
    return (elapsedMonths + 1);
}

function getDay(uint256 timestamp) public pure returns (uint256) {
    uint256 secondsInDay = 86400; // 24 hours
    return ((timestamp / secondsInDay) % 30 + 1);
}

function getYearStartTimestamp(uint256 year) public pure returns (uint256) {
    uint256 secondsInYear = 31536000; // 365 days
    return (year - 1970) * secondsInYear;
}


    function balanceStaked(string memory tokenUri,address owner) external view returns(uint){
        uint tokenId=_market.getRoyalty(tokenUri).tokenId;
        return stakingInfo[tokenUri][msg.sender].quantity ;
    }

}
