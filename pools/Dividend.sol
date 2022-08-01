// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libs/Auth.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Dividend is ERC20, Auth {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address loganAddress;
    // todo set init lock days
    uint256 public lockTime = 90 * 1 days; // 90 days;

    mapping(address => LockInfo) public userLockInfo;

    struct LockInfo {
        uint256 lastLockTime;
        uint256 unlockingSpeed;
    }


    constructor(address _loganAddress, string memory name, string memory symbol) ERC20 (name, symbol) {
        loganAddress = _loganAddress;
    }

    // Enter the bar. Pay some TOKENs. Earn some shares.
    // Locks Token and mints xToken
    function enter(uint256 _amount) public {
        // Gets the amount of Token locked in the contract
        uint256 totalLogan = IERC20(loganAddress).balanceOf(address(this));
        // Gets the amount of xToken in existence
        uint256 totalShares = totalSupply();
        // If no xToken exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalLogan == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xToken the Token is worth. The ratio will change overtime, as xToken is burned/minted and Token deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalLogan);
            _mint(msg.sender, what);
        }
        // Lock the Token in the contract
        IERC20(loganAddress).transferFrom(msg.sender, address(this), _amount);
        userLockInfo[msg.sender].lastLockTime = block.timestamp;
    }

    // Enter the bar. Pay some TOKENs. Earn some shares.
    // Locks Token and mints xToken
    function enterView(uint256 _amount) public view returns(uint256 getAmount) {
        // Gets the amount of Token locked in the contract
        uint256 totalLogan = IERC20(loganAddress).balanceOf(address(this));
        // Gets the amount of xToken in existence
        uint256 totalShares = totalSupply();
        // If no xToken exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalLogan == 0) {
            getAmount = _amount;
        }
        // Calculate and mint the amount of xToken the Token is worth. The ratio will change overtime, as xToken is burned/minted and Token deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalLogan);
            getAmount = what;
        }
    }


    // Leave the bar. Claim back your TOKENs.
    // Unlocks the staked + gained Token and burns xToken
    function leave(uint256 _share) public {
        uint256 timeDifference = block.timestamp.sub(userLockInfo[msg.sender].lastLockTime);
        require(lockTime < timeDifference, 'Lock time is not satisfied');

        // Gets the amount of xToken in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Token the xToken is worth
        uint256 what = _share.mul(IERC20(loganAddress).balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        IERC20(loganAddress).transfer(msg.sender, what);
    }

    // Leave the bar. Claim back your TOKENs.
    // Unlocks the staked + gained Token and burns xToken
    function leaveView(uint256 _share) public view returns(uint256 what) {
        uint256 timeDifference = block.timestamp.sub(userLockInfo[msg.sender].lastLockTime);
        // Gets the amount of xToken in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Token the xToken is worth
        if(totalShares == 0) {
            what = 0;
        } else {
            what = _share.mul(IERC20(loganAddress).balanceOf(address(this))).div(totalShares);
        }
    }

    function setLockDays(uint256 _num, uint256 _scale) public onlyOperator {
        lockTime = (_num * 1 days).div(_scale);
    }

}
