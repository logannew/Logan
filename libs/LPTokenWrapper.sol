pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Auth.sol";
import "./Governance.sol";

contract LPTokenWrapper is Auth,Governance {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public _lpToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    uint256 private _totalPower;
    mapping(address => uint256) private _powerBalances;

    struct MortgageNft {
        uint256 tokenId;
        uint8 level;
        uint8 accelerate;
    }

    mapping(address => MortgageNft) public _userMortgageNft;

    //    address public _powerStrategy = address(0x0);

    //    function setPowerStrategy(address strategy) public onlyGovernance {
    //        _powerStrategy = strategy;
    //    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOfPower(address account) public view returns (uint256) {
        return _powerBalances[account];
    }

    function totalPower() public view returns (uint256) {
        return _totalPower;
    }

    function updateRewardAutomatic(address player) public virtual {}

    //    function updateStrategyPower(address player) public override {
    //        if (_powerStrategy != address(0x0)) {
    //            if(_totalPower > 0) {
    //                _totalPower = _totalPower.sub(_powerBalances[player]);
    //            }
    //            _powerBalances[player] = IPowerStrategy(_powerStrategy).getPower(player);
    //            _totalPower = _totalPower.add(_powerBalances[player]);
    //        }
    //    }

    function setMortgageNft(address _account, uint256 _tokenId, uint8 _level, uint8 _accelerate) public onlyOperator {
        require(_userMortgageNft[_account].tokenId == 0, "Only one NFT can be mortgaged!");
        require(_balances[_account] > 0, "Please mortgage the LP first!");

        updateRewardAutomatic(_account);

        _userMortgageNft[_account] = MortgageNft({
            tokenId: _tokenId,
            level: _level,
            accelerate: _accelerate
        });

        _totalPower = _totalPower.sub(_powerBalances[_account]);
        _powerBalances[_account] = _balances[_account].mul(100 + uint256(_accelerate)).div(100);
        _totalPower = _totalPower.add(_powerBalances[_account]);
    }

    function withdrawMortgageNft(address _account) public onlyOperator {
        require(_userMortgageNft[_account].tokenId > 0, "No redeemable NFT!");

        updateRewardAutomatic(_account);

        _userMortgageNft[_account] = MortgageNft({
            tokenId: 0,
            level: 0,
            accelerate: 0
        });

        _totalPower = _totalPower.sub(_powerBalances[_account]);
        _powerBalances[_account] = _balances[_account];
        _totalPower = _totalPower.add(_powerBalances[_account]);
    }

    function stake(uint256 amount) public virtual{
        require(amount > 0, "amount > 0");

        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);

        //        if (_powerStrategy != address(0x0)) {
        //            IPowerStrategy(_powerStrategy).lpIn(msg.sender, amount);
        //        } else {
        //            _totalPower = _totalSupply;
        //            _powerBalances[msg.sender] = _balances[msg.sender];
        //        }

        uint8 accelerate = _userMortgageNft[msg.sender].accelerate;

        if (accelerate > 0) {
            _totalPower = _totalPower.sub(_powerBalances[msg.sender]);
            _powerBalances[msg.sender] = _balances[msg.sender].mul(100 + uint256(accelerate)).div(100);
            _totalPower = _totalPower.add(_powerBalances[msg.sender]);
        } else {
            //            _totalPower = _totalPower.sub(_powerBalances[msg.sender]);
            //            _totalPower = _totalPower.add(_balances[msg.sender]);
            _totalPower = _totalPower.add(amount);
            _powerBalances[msg.sender] = _balances[msg.sender];
        }

        _lpToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual{
        require(amount > 0, "amount > 0");

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);

        //        if (_powerStrategy != address(0x0)) {
        //            IPowerStrategy(_powerStrategy).lpOut(msg.sender, amount);
        //        } else {
        //            _totalPower = _totalSupply;
        //            _powerBalances[msg.sender] = _balances[msg.sender];
        //        }

        uint8 accelerate = _userMortgageNft[msg.sender].accelerate;

        if (accelerate > 0) {
            _totalPower = _totalPower.sub(_powerBalances[msg.sender]);
            _powerBalances[msg.sender] = _balances[msg.sender].mul(100 + uint256(accelerate)).div(100);
            _totalPower = _totalPower.add(_powerBalances[msg.sender]);
        } else {
            //            _totalPower = _totalPower.sub(_powerBalances[msg.sender]);
            //            _totalPower = _totalPower.add(_balances[msg.sender]);
            _totalPower = _totalPower.sub(amount);
            _powerBalances[msg.sender] = _balances[msg.sender];
        }

        _lpToken.safeTransfer(msg.sender, amount);
    }

}
