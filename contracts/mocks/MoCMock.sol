// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MoCMock {
    bool public unstoppable;

    event MadeUnstoppable();

    function makeUnstoppable() external {
        unstoppable = true;
        emit MadeUnstoppable();
    }
}
