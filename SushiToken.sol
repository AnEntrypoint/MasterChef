// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "masterchefcontracts/token/ERC20/ERC20.sol";
import "masterchefcontracts/access/Ownable.sol";


// SushiToken without Governance.
contract SushiToken is ERC20("SushiToken", "SUSHI"), Ownable {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}