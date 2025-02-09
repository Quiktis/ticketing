// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Counter {
    struct CounterStorage {
        uint256 _value;
    }

    function current(CounterStorage storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(CounterStorage storage counter) internal returns (uint256) {
        unchecked {
            counter._value += 1;
        }
        return counter._value;
    }

    function decrement(CounterStorage storage counter) internal returns (uint256) {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
        return counter._value;
    }

    function reset(CounterStorage storage counter) internal returns (uint256) {
        counter._value = 0;
        return counter._value;
    }
}
