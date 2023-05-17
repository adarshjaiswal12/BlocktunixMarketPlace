// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract APT721 is ERC721URIStorage {
    address public  admin;
    address public market;
    
    constructor() ERC721(" Apptunix NFT", "APT") {
        admin=msg.sender;
    }


    function mint(address to,string memory tokenURI,uint tokenId) external {
        require( msg.sender==market , "Token_721: Unauthorized minting" );
        // _tokenId++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
       
    }


    function setMarketAddress () external {
        require(market==address(0),"Token_721: Market already set");
        require( tx.origin == admin, "Token_721: Forbidden function call" );
        market = msg.sender;   
    }


}

