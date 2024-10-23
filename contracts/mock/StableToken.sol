// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableToken is ERC20 {
    constructor() ERC20("StableToken", "STB") {
        _mint(msg.sender, 10 * decimals());
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
