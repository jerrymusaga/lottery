// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IFlareDaemonize.sol";
import "./interfaces/IFlareRandomness.sol";
import "./interfaces/ITimeAutomation.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract Lottery is IFlareDaemonize, Ownable {
   
    IFlareRandomness public immutable flareRandomness;
    ITimeAutomation public immutable timeAutomation;
    
    
    uint256 public constant TICKET_PRICE = 0.01 ether;
    uint256 public constant DRAW_INTERVAL = 5 minutes;
    uint256 public constant MIN_PLAYERS = 2;
    
   
    address[] public players;
    uint256 public lotteryId;
    uint256 public lastDrawTime;
    uint256 public randomnessRequestId;
    bool public lotteryActive;
    bool public randomnessRequested;
    
    
    mapping(uint256 => address) public lotteryWinners;
    mapping(uint256 => uint256) public lotteryPrizes;
    
   
    event PlayerEntered(address indexed player, uint256 indexed lotteryId);
    event LotteryDrawRequested(uint256 indexed lotteryId, uint256 requestId);
    event WinnerSelected(uint256 indexed lotteryId, address indexed winner, uint256 prize);
    event LotteryReset(uint256 indexed lotteryId);
    
    
    constructor(address _flareRandomness, address _timeAutomation) Ownable(msg.sender) {
        flareRandomness = IFlareRandomness(_flareRandomness);
        timeAutomation = ITimeAutomation(_timeAutomation);
        
        lastDrawTime = block.timestamp;
        lotteryId = 1;
        lotteryActive = true;
        
    
        timeAutomation.registerForTimeTrigger(DRAW_INTERVAL);
    }
    
    
    function enterLottery() external payable {
        require(lotteryActive, "Lottery is not active");
        require(msg.value == TICKET_PRICE, "Incorrect ticket price");
        
        players.push(msg.sender);
        emit PlayerEntered(msg.sender, lotteryId);
    }
    
    
    function daemonize() external override returns (bool) {
        // Ensure only Flare daemon can call this
        require(msg.sender == address(timeAutomation), "Unauthorized caller");
        
        if (shouldDrawLottery()) {
            requestRandomness();
            return true;
        }
        
        return false;
    }
    
    
     //Check if lottery should be drawn (time elapsed and enough players)
    function shouldDrawLottery() public view returns (bool) {
        return (
            lotteryActive &&
            !randomnessRequested &&
            block.timestamp >= lastDrawTime + DRAW_INTERVAL &&
            players.length >= MIN_PLAYERS
        );
    }
    
    
    function requestRandomness() internal {
        require(lotteryActive, "Lottery is not active");
        require(!randomnessRequested, "Randomness already requested");
        require(players.length >= MIN_PLAYERS, "Not enough players");
        
        randomnessRequestId = flareRandomness.requestRandomWords(1);
        randomnessRequested = true;
        
        emit LotteryDrawRequested(lotteryId, randomnessRequestId);
    }
    
   
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
        require(msg.sender == address(flareRandomness), "Unauthorized fulfillment");
        require(randomnessRequested, "No randomness requested");
        require(_requestId == randomnessRequestId, "Request ID mismatch");
        
        selectWinner(_randomWords[0]);
        
        resetLottery();
    }
    
   
    function selectWinner(uint256 _randomWord) internal {
        uint256 winnerIndex = _randomWord % players.length;
        address winner = players[winnerIndex];
        
        uint256 prize = address(this).balance * 98 / 100; 
        
        lotteryWinners[lotteryId] = winner;
        lotteryPrizes[lotteryId] = prize;
        
       
        (bool sent, ) = payable(winner).call{value: prize}("");
        require(sent, "Failed to send prize");
        
        emit WinnerSelected(lotteryId, winner, prize);
    }
    
   
    function resetLottery() internal {
        lotteryId++;
        
        delete players;
        
        lastDrawTime = block.timestamp;
        randomnessRequested = false;
        
        emit LotteryReset(lotteryId);
    }
    
    
    function setLotteryActive(bool _active) external onlyOwner {
        lotteryActive = _active;
    }
    
   
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        (bool sent, ) = payable(owner()).call{value: balance}("");
        require(sent, "Failed to withdraw fees");
    }
    
    
    function getLotteryInfo() external view returns (
        uint256 _lotteryId,
        uint256 _playerCount,
        uint256 _prize,
        uint256 _timeUntilNextDraw,
        bool _isActive
    ) {
        return (
            lotteryId,
            players.length,
            address(this).balance,
            lastDrawTime + DRAW_INTERVAL > block.timestamp ? lastDrawTime + DRAW_INTERVAL - block.timestamp : 0,
            lotteryActive
        );
    }
    
    
    function getPlayers() external view returns (address[] memory) {
        return players;
    }
    
    
    receive() external payable {
        require(msg.value == TICKET_PRICE, "Incorrect amount for ticket");
        players.push(msg.sender);
        emit PlayerEntered(msg.sender, lotteryId);
    }
}