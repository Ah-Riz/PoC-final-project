// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title WrappedMNT (WMNT)
 * @notice Wrap native MNT into ERC20 token for use in Privacy PoC
 * @dev Similar to WETH on Ethereum
 */
contract WrappedMNT is ERC20 {
    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);

    constructor() ERC20("Wrapped MNT", "WMNT") {}

    /**
     * @notice Deposit native MNT and receive WMNT tokens
     */
    function deposit() public payable {
        require(msg.value > 0, "Must send MNT");
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw WMNT tokens and receive native MNT
     * @param amount Amount of WMNT to unwrap
     */
    function withdraw(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient WMNT balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Deposit MNT by sending to contract
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice Fallback function
     */
    fallback() external payable {
        deposit();
    }
}
