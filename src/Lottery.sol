// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

contract Lottery { 
    event LotteryEnter(address indexed player);


    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;

    enum LotteryState {
        OPEN,
        CALCULATING
    }
    LotteryState private s_lotteryState;

    constructor(uint256 entranceFee){
        i_entranceFee = entranceFee;
    }

    function enterLottery() public payable {
        require(s_lotteryState == LotteryState.OPEN, "Lottery is not open");
        require(msg.value >= i_entranceFee, "Broke");
        s_players.push(payable(msg.sender));
        emit LotteryEnter(msg.sender);
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
    
    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
