pragma solidity ^0.5.8;


import "./Common.sol";

//sun平台挖矿合约无法代理用户操作，在没有自己资金池的情况下，无法合约直接调用合约

interface IMine {
    function stake(uint256 amount) external;

    function earned(address account) external view returns (uint256);

    function withdraw(uint256 amount) external;
}

contract TokenMineTool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeTRC20 for ITRC20;


    ITRC20 public mineToken;
    IMine public minePool;
    address payable public finance;
    uint256 public depositTradingFee;
    uint256 public withdrawTradingFee;
    bool public paused = false;

    function pause() external onlyOwner  {
        paused = true;
    }

    function unPause() external onlyOwner {
        paused = false;
    }

    constructor (address _mineToken, address _minePool) external {
        mineToken = ITRC20(_mineToken);
        minePool = IMine(_minePool);
        finance = msg.sender;
        depositTradingFee = 10;
        withdrawTradingFee = 10;
    }

    function() external payable {
    }

    function setMineToken(address _mineToken) external onlyOwner {
        mineToken = ITRC20(_mineToken);
    }

    function setMinePool(address _poolToken) external onlyOwner {
        poolToken = IMine(_poolToken);
    }

    function setFinanceAddress(address payable _financeAddress) external onlyOwner returns(bool) {
        finance = _financeAddress;
        return true;
    }

    function setDepositTradingFee(uint256 _value) external onlyOwner returns(bool) {
        depositTradingFee = _value;
        return true;
    }

    function setWithdrawTradingFee(uint256 _value) external onlyOwner returns(bool) {
        withdrawTradingFee = _value;
        return true;
    }

    function getInfo() public view returns (address, address, address payable, uint256, uint256) {
        return (address(mineToken), address(minePool), finance, depositTradingFee, withdrawTradingFee);
    }


    function deposit(uint256 amount) external returns(bool) {
        require(!paused, "the service is paused");
        require(amount > 0);
        return depositSub(amount);
    }

    function depositSub(uint256 amount) private nonReentrant returns(bool) {
        mineToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 _value = mineToken.allowance(address(this), address(minePool));
        if (_value < amount) {
            mineToken.safeApprove(address(minePool), uint256(-1));
        }
        uint256 _a = amount.mul(depositTradingFee).div(10000);
        uint _b = amount.sub(_a);
        if (_b > 0) {
            minePool.stake(_b);
        }
        if (_a > 0) {
            mineToken.transfer(finance, _a);
        }
        return true;
    }

    function earned(address account) external view returns (uint256) {
        return 0;
    }

    function withdraw(uint256 amount) external returns(bool) {
        require(!paused, "the service is paused");
        require(amount > 0);
        return withdrawSub(amount);
    }

    function withdrawSub(uint256 amount) private nonReentrant returns(bool) {
        return true;
    }

}