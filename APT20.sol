// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardToken is ERC20 {
    address public  admin;
    address public staking;
    constructor() ERC20("Reward Token", "RWT") {
         admin=msg.sender;
    }
    function mint(address to,uint amount) external {
        require( msg.sender==staking , "Token_20: Unauthorized minting" );
        _mint(to, amount);
       
    }


    function setSatkingAddress () external {
        require(staking==address(0),"Token_reward: Staking contract already set");
        require( tx.origin == admin, "Token_reward: Forbidden function call" );
        staking = msg.sender;   
    }
}
