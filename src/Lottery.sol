// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// // Importing Flare VRF and Time-Based Automation interfaces
// import "@flarenetwork/flare-periphery-contracts/contracts/randomness/interface/IFlareDaemonize.sol";
// import "@flarenetwork/flare-periphery-contracts/contracts/randomness/interface/IFlareRandomness.sol";
// import "@flarenetwork/flare-periphery-contracts/contracts/automation/interface/ITimeAutomation.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// /**
//  * @title FlareLottery
//  * @dev An automated lottery contract that selects winners every 5 minutes using Flare VRF
//  */
// contract FlareLottery is IFlareDaemonize, Ownable, ReentrancyGuard {
//     // Flare interfaces
//     IFlareRandomness public immutable flareRandomness;
//     ITimeAutomation public immutable timeAutomation;
    
//     // Lottery configuration
//     uint256 public constant TICKET_PRICE = 0.01 ether;
//     uint256 public constant DRAW_INTERVAL = 5 minutes;
//     uint256 public constant MIN_PLAYERS = 2;
    
//     // Lottery state variables
//     address[] public players;
//     uint256 public lotteryId;
//     uint256 public lastDrawTime;
//     uint256 public randomnessRequestId;
//     bool public lotteryActive;
//     bool public randomnessRequested;
    
//     // Mapping from lottery ID to winner
//     mapping(uint256 => address) public lotteryWinners;
//     // Mapping from lottery ID to prize amount
//     mapping(uint256 => uint256) public lotteryPrizes;
    
//     // Events
//     event PlayerEntered(address indexed player, uint256 indexed lotteryId);
//     event LotteryDrawRequested(uint256 indexed lotteryId, uint256 requestId);
//     event WinnerSelected(uint256 indexed lotteryId, address indexed winner, uint256 prize);
//     event LotteryReset(uint256 indexed lotteryId);
    
//     /**
//      * @dev Constructor initializes the Flare VRF and Time Automation interfaces
//      * @param _flareRandomness Address of the Flare Randomness contract
//      * @param _timeAutomation Address of the Time Automation contract
//      */
//     constructor(address _flareRandomness, address _timeAutomation) Ownable(msg.sender) {
//         flareRandomness = IFlareRandomness(_flareRandomness);
//         timeAutomation = ITimeAutomation(_timeAutomation);
        
//         lastDrawTime = block.timestamp;
//         lotteryId = 1;
//         lotteryActive = true;
        
//         // Register with timeAutomation for 5-minute interval triggers
//         timeAutomation.registerForTimeTrigger(DRAW_INTERVAL);
//     }
    
//     /**
//      * @dev Allows a player to enter the lottery by sending the ticket price
//      */
//     function enterLottery() external payable {
//         require(lotteryActive, "Lottery is not active");
//         require(msg.value == TICKET_PRICE, "Incorrect ticket price");
        
//         players.push(msg.sender);
//         emit PlayerEntered(msg.sender, lotteryId);
//     }
    
//     /**
//      * @dev Trigger the lottery draw if conditions are met
//      * This function is called by the Flare Time Automation service
//      */
//     function daemonize() external override returns (bool) {
//         // Ensure only Flare daemon can call this
//         require(msg.sender == address(timeAutomation), "Unauthorized caller");
        
//         if (shouldDrawLottery()) {
//             requestRandomness();
//             return true;
//         }
        
//         return false;
//     }
    
//     /**
//      * @dev Check if lottery should be drawn (time elapsed and enough players)
//      */
//     function shouldDrawLottery() public view returns (bool) {
//         return (
//             lotteryActive &&
//             !randomnessRequested &&
//             block.timestamp >= lastDrawTime + DRAW_INTERVAL &&
//             players.length >= MIN_PLAYERS
//         );
//     }
    
//     /**
//      * @dev Request randomness from Flare VRF
//      */
//     function requestRandomness() internal {
//         require(lotteryActive, "Lottery is not active");
//         require(!randomnessRequested, "Randomness already requested");
//         require(players.length >= MIN_PLAYERS, "Not enough players");
        
//         randomnessRequestId = flareRandomness.requestRandomWords(1);
//         randomnessRequested = true;
        
//         emit LotteryDrawRequested(lotteryId, randomnessRequestId);
//     }
    
//     /**
//      * @dev Callback function for Flare VRF
//      * @param _requestId The ID of the randomness request
//      * @param _randomWords The array of random words generated
//      */
//     function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
//         require(msg.sender == address(flareRandomness), "Unauthorized fulfillment");
//         require(randomnessRequested, "No randomness requested");
//         require(_requestId == randomnessRequestId, "Request ID mismatch");
        
//         // Select winner using the random number
//         selectWinner(_randomWords[0]);
        
//         // Reset lottery for next round
//         resetLottery();
//     }
    
//     /**
//      * @dev Select winner based on random number
//      * @param _randomWord The random word from Flare VRF
//      */
//     function selectWinner(uint256 _randomWord) internal {
//         uint256 winnerIndex = _randomWord % players.length;
//         address winner = players[winnerIndex];
        
//         // Calculate prize (keep small fee for contract)
//         uint256 prize = address(this).balance * 98 / 100; // 2% fee
        
//         // Record winner and prize
//         lotteryWinners[lotteryId] = winner;
//         lotteryPrizes[lotteryId] = prize;
        
//         // Transfer prize to winner
//         (bool sent, ) = payable(winner).call{value: prize}("");
//         require(sent, "Failed to send prize");
        
//         emit WinnerSelected(lotteryId, winner, prize);
//     }
    
//     /**
//      * @dev Reset lottery for next round
//      */
//     function resetLottery() internal {
//         // Increment lottery ID
//         lotteryId++;
        
//         // Clear players array
//         delete players;
        
//         // Reset lottery state
//         lastDrawTime = block.timestamp;
//         randomnessRequested = false;
        
//         emit LotteryReset(lotteryId);
//     }
    
//     /**
//      * @dev Allow owner to pause/unpause the lottery
//      * @param _active New state of the lottery
//      */
//     function setLotteryActive(bool _active) external onlyOwner {
//         lotteryActive = _active;
//     }
    
//     /**
//      * @dev Allow owner to withdraw fees
//      */
//     function withdrawFees() external onlyOwner nonReentrant {
//         uint256 balance = address(this).balance;
//         require(balance > 0, "No balance to withdraw");
        
//         (bool sent, ) = payable(owner()).call{value: balance}("");
//         require(sent, "Failed to withdraw fees");
//     }
    
//     /**
//      * @dev Get current lottery state
//      */
//     function getLotteryInfo() external view returns (
//         uint256 _lotteryId,
//         uint256 _playerCount,
//         uint256 _prize,
//         uint256 _timeUntilNextDraw,
//         bool _isActive
//     ) {
//         return (
//             lotteryId,
//             players.length,
//             address(this).balance,
//             lastDrawTime + DRAW_INTERVAL > block.timestamp ? 
//                 lastDrawTime + DRAW_INTERVAL - block.timestamp : 0,
//             lotteryActive
//         );
//     }
    
//     /**
//      * @dev Get list of players for current lottery
//      */
//     function getPlayers() external view returns (address[] memory) {
//         return players;
//     }
    
//     /**
//      * @dev Fallback function to handle direct deposits
//      */
//     receive() external payable {
//         require(msg.value == TICKET_PRICE, "Incorrect amount for ticket");
//         players.push(msg.sender);
//         emit PlayerEntered(msg.sender, lotteryId);
//     }
// }