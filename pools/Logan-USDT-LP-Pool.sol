// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libs/LPTokenWrapper.sol";
import "../interface/IMDexFactory.sol";
import "../interface/ILock.sol";

// POL Pool / Logan-USDT Pool
contract Logan_USDT_LP_Pool is LPTokenWrapper {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public _base;
    IMdexFactory public _factory;
    IERC20 public _usdt;
    IERC20 public _logan;
    address public feeAddress;
    uint256 public constant DURATION = 1 days;
    uint256 public _punishTime = 3 days;
    uint256 public _startTime;
    uint256 public _periodFinish = 0;
    uint256 public _rewardRate = 0;
    uint256 public _lastUpdateTime;
    uint256 public _rewardPerTokenStored;
    uint8 public percentage_fee = 15;
    // Tax and fee less than three days
    uint8 public percentage_punish = 10;
    // lock fee
    uint8 public lock_position_fee = 25;
    address public _lockAddress;

    mapping(address => uint256) public _userRewardPerTokenPaid;
    mapping(address => uint256) public _rewards;
    mapping(address => uint256) public _lastStakedTime;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event transferToDividend(address indexed user, uint256 amount);

    constructor (
    // get token
        address base,
        address lpToken,
        uint startTime,
    // 1 days
        uint256 rewardRate_,
        uint256 days_
    ) public {
        _base = IERC20(base);
        _lpToken = IERC20(lpToken);
        _startTime = startTime;
        _rewardRate = uint(rewardRate_).div(DURATION);
        _periodFinish = startTime + (days_ * 24 * 3600);
    }

    modifier updateReward(address account) {
        _rewardPerTokenStored = rewardPerToken();
        _lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = _rewardPerTokenStored;
        }
        _;
    }

    function setPercentageFee(uint8 value) public onlyGovernance {
        percentage_fee = value;
    }

    function setPercentagePunish(uint8 value) public onlyGovernance {
        percentage_punish = value;
    }

    function setlpPairAddress(address _addr0, address _addr1) public onlyGovernance {
        _logan = IERC20(_addr0);
        _usdt = IERC20(_addr1);
    }

    function setFactoryAddress(address _addr) public onlyGovernance {
        _factory = IMdexFactory(_addr);
    }

    function setBase(address base) public onlyGovernance {
        _base = IERC20(base);
    }

    function setStartTime(uint256 startTime) public onlyGovernance {
        _startTime = startTime;
    }

    function setPeriodFinish(uint256 periodFinish) public onlyGovernance {
        _periodFinish = periodFinish;
    }

    // how many token one second
    function setRewardRate(uint256 rate) public onlyGovernance {
        _rewardPerTokenStored = rewardPerToken();
        _lastUpdateTime = lastTimeRewardApplicable();
        _rewardRate = rate;
    }

    function setLockAddress(address _lock) public onlyGovernance {
        _lockAddress = _lock;
    }

    function setFeeAddress(address _address) public onlyGovernance {
        feeAddress = _address;
    }

    function setWithDrawPunishTime(uint256 punishTime) public onlyGovernance {
        _punishTime = punishTime;
    }

    function updateRewardAutomatic(address account) public override {
        _rewardPerTokenStored = rewardPerToken();
        _lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = _rewardPerTokenStored;
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, _periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalPower() == 0) {
            return _rewardPerTokenStored;
        }
        return
        _rewardPerTokenStored.add(
            lastTimeRewardApplicable()
            .sub(_lastUpdateTime)
            .mul(_rewardRate)
            .mul(1e18)
            .div(totalPower())
        );
    }

    function earned(address account) public view returns (uint256) {
        return
        getPower(account)
        .mul(rewardPerToken().sub(_userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(_rewards[account]);
    }

    function stake(uint256 amount)
    public
    override
    updateReward(msg.sender)
    checkStart
    {
        require(amount > 0, "Cannot stake 0");
        super.stake(amount);
        _lastStakedTime[msg.sender] = block.timestamp;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
    public
    override
    updateReward(msg.sender)
    checkStart
    {
        require(amount > 0, "Cannot withdraw 0");
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external checkStart {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkStart {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            _rewards[msg.sender] = 0;
            uint256 fee = reward.mul(percentage_fee).div(100);
            if (fee > 0) {
                _base.safeTransfer(feeAddress, fee);
            }

            uint256 punishAmount;
            if (block.timestamp < (_lastStakedTime[msg.sender] + _punishTime)) {
                punishAmount = reward.mul(percentage_punish).div(100);
                if (punishAmount > 0) {
                    _base.safeTransfer(feeAddress, punishAmount);
                }
            }

            emit transferToDividend(msg.sender, fee.add(punishAmount));

            uint256 leftReward = reward.sub(fee).sub(punishAmount);
            uint256 unLockAmount = leftReward.mul(lock_position_fee).div(100);
            _base.safeTransfer(msg.sender, unLockAmount);

            uint256 lockVolume = leftReward.sub(unLockAmount);
            _base.safeTransfer(_lockAddress, lockVolume);
            ILock(_lockAddress).addLockVolume(msg.sender, lockVolume);
            emit RewardPaid(msg.sender, leftReward);
        }
    }

    modifier checkStart() {
        require(block.timestamp > _startTime, "not start");
        _;
    }

    function isStart() public view returns (bool) {
        return block.timestamp > _startTime;
    }

    function balanceOfBase() public view returns (uint) {
        return _base.balanceOf(address(this));
    }


    function getPower(address user) public view returns (uint256) {
        return super.balanceOfPower(user);
    }

    function getUserPunishTime(address user) public view returns (uint) {
        if (_lastStakedTime[user] <= 0) {
            return 0;
        }
        if ((_lastStakedTime[user] + _punishTime) <= block.timestamp) {
            return 0;
        }
        return (_lastStakedTime[user] + _punishTime);
    }

//    function getBestSegment() public view returns (uint, uint) {
//        uint max = IPowerStrategy(_powerStrategy).getSegmentMax(1);
//        uint max2 = IPowerStrategy(_powerStrategy).getSegmentMax(2);
//        return (max, max2);
//    }

    function getDailyReward() public view returns (uint) {
        return _rewardRate * 1 days;
    }

    function getTLV() public view returns (uint) {
        return (_lpToken.balanceOf(address(this)) * getUsdtFromLP() * 2) / (_lpToken.totalSupply());
    }

    function getUsdtFromLP() public view returns (uint) {
        (,uint amountUsdt) = _factory.getReserves(address(_logan), address(_usdt));
        return amountUsdt;
    }

    function getAPR() public view returns (uint) {
        if (getTLV() <= 0) {
            return 0;
        }
        return (_rewardRate * 1 days * 365 * getBSDPrice() * 100) / (getTLV());
    }

    function getPersonalAPR(address user) public view returns (uint) {
        if (totalPower() == 0 || balanceOf(user) == 0) {
            return 0;
        }
        uint a = (_rewardRate * 1 days * 365 * getPower(user) * getBSDPrice()) / (totalPower());
        uint b = balanceOf(user) * getUsdtFromLP() * 2 / _lpToken.totalSupply();
        return a * 100 / b;
    }

    function getPUSDPrice() public view returns (uint) {
        (uint amountPusd,uint amountUsdt) = _factory.getReserves(address(_logan), address(_usdt));
        return amountUsdt / amountPusd;
    }

    function getBSDPrice() public view returns (uint) {
        (uint amountBSD, uint amountPUSD) = _factory.getReserves(address(_base), address(_logan));
        (uint amountPusd, uint amountUsdt) = _factory.getReserves(address(_logan), address(_usdt));
        return (amountPUSD * amountUsdt) / (amountPusd * amountBSD);
    }

}
