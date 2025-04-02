// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery lottery;
    address mockRandomness = address(0x1);
    address mockTimeAutomation = address(0x2);
    

    address player1 = address(0x100);
    address player2 = address(0x200);
    
    function setUp() public {
        
        vm.mockCall(
            mockTimeAutomation,
            abi.encodeWithSelector(ITimeAutomation.registerForTimeTrigger.selector),
            abi.encode()
        );
        
        lottery = new Lottery(mockRandomness, mockTimeAutomation);
    }
    
    function testEnterLottery() public {
        
        vm.deal(player1, 1 ether);
        
     
        vm.prank(player1);
        lottery.enterLottery{value: 0.01 ether}();
        
       
        address[] memory players = lottery.getPlayers();
        assertEq(players.length, 1);
        assertEq(players[0], player1);
    }
    
    function testLotteryDraw() public {
        
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        
        vm.prank(player1);
        lottery.enterLottery{value: 0.01 ether}();
        
        vm.prank(player2);
        lottery.enterLottery{value: 0.01 ether}();
        
        
        vm.warp(block.timestamp + 5 minutes);
        
        // Mock randomness request
        uint256 mockRequestId = 123;
        vm.mockCall(
            mockRandomness,
            abi.encodeWithSelector(IFlareRandomness.requestRandomWords.selector),
            abi.encode(mockRequestId)
        );
        
        // Execute as time automation
        vm.prank(mockTimeAutomation);
        lottery.daemonize();
        
       
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0; // This will select the first player as winner
        
      
        vm.prank(mockRandomness);
        lottery.fulfillRandomWords(mockRequestId, randomWords);
        
        // Verify lottery was reset
        assertEq(lottery.lotteryId(), 2);
        assertEq(lottery.getPlayers().length, 0);
    }
}