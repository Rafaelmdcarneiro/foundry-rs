// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeFiStableCoin
 * @author Jeremiah A.
 * Collateral: Exogenous
 * Minting (Stability Mechanism): DeFi (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 * This is the contract meant to be owned by DSCEngine.
 * It is a ERC20 token that can be minted and burned by the DSCEngine smart contract.
 */
contract DeFiStableCoin is ERC20Burnable, Ownable {
    error DeFiStableCoin__AmountMustBeMoreThanZero();
    error DeFiStableCoin__BurnAmountExceedsBalance();
    error DeFiStableCoin__NotZeroAddress();

    /*
    In future versions of OpenZeppelin contracts package, Ownable must be declared with an address of the contract owner
    as a parameter.
    For example:
    constructor() ERC20("DeFiStableCoin", "DSC") Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) {}
    Related code changes can be viewed in this commit:
    */

    constructor() ERC20("DeFiStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert DeFiStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DeFiStableCoin__BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool, uint256) {
        if (_to == address(0)) {
            revert DeFiStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DeFiStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);

        return (true, _amount);
    }
}
