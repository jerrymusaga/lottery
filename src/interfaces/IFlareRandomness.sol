// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFlareRandomness {
    function requestRandomWords(uint256 numWords) external returns (uint256 requestId);
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}