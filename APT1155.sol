// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";



contract APT1155 is ERC1155URIStorage {
    address public  admin;
    address public  market;
    // uint private _tokenId=0;
    //  struct RoyaltyInfo {
    //     address creator;
    //     uint tokenType;
    //     uint256 royaltyPercentage;
    // }

    // mapping(string => RoyaltyInfo) public  _tokenRoyaltyInfo;


    constructor() ERC1155("") {
        admin= msg.sender ;
    }


    function mint(address account, uint256 amount,string memory tokenURI,uint256 tokenId) external {
        require(msg.sender == market , "Token_1155:Unautherized minting");
        // _tokenId++;
        _mint(account, tokenId, amount, "");
        _setURI(tokenId, tokenURI);
        // _tokenRoyaltyInfo[tokenURI].creator = account;
        // _tokenRoyaltyInfo[tokenURI].tokenType=1155;
        // _tokenRoyaltyInfo[tokenURI].royaltyPercentage=royaltypercentage;
    } 

    function setMarketAddress() external {
        require(market==address(0),"Token_1155 : Market already set");
        require( tx.origin == admin, "Token_1155 : Forbidden function call" );
        market = msg.sender;   
    }

}
