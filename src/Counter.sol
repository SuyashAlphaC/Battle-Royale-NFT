//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

contract Counter {
    uint256 public counter;

    function increment() public {
        counter ++ ;
    }

    function decrement() public {
        counter --;
    }

    function getCounter() public view returns(uint256) {
        return counter;
    }
}