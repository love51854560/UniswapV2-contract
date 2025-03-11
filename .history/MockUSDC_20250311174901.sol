// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";

/**
 * @title MockUSDC
 * @dev A mock implementation of USDC stablecoin for testing
 */
contract MockUSDC is MockERC20 {
    constructor(address initialOwner) 
        MockERC20("USD Coin", "USDC", 6, initialOwner) {
        // USDC has 6 decimals
    }

    /**
     * @dev Faucet function to get test USDC
     * @param to The address to receive tokens
     * @param amount The amount of tokens to mint (in USDC units)
     */
    function faucet(address to, uint256 amount) external {
        require(amount <= 10000 * 10**6, "MockUSDC: Maximum faucet amount exceeded");
        _mint(to, amount);
    }
}