// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITimeAutomation {
    function registerForTimeTrigger(uint256 interval) external;
}