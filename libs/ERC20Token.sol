// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract ERC20Token is
ERC20
{
    constructor(string memory name, string memory symbol) ERC20 (name, symbol) {
        _mint(msg.sender, 100000000 * 10e17);
    }

    function decimals() public view override returns (uint8) {
        return 18;
    }
}
