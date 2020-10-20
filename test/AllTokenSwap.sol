pragma solidity ^0.5.8;


import "./Common.sol";


interface ITokenSwap {

    function tokenToTrxTransferInput(
        uint256 tokens_sold,
        uint256 min_trx,
        uint256 deadline,
        address recipient)
    external returns (uint256);


    function tokenToTokenTransferInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_trx_bought,
        uint256 deadline,
        address recipient,
        address token_addr)
    external returns (uint256);

    function trxToTokenTransferInput(
        uint256 min_tokens,
        uint256 deadline,
        address recipient)
    external payable returns(uint256);

    function tokenAddress() external view returns (address);
}

contract AllTokenSwap is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeTRC20 for ITRC20;

    //ITRC20 public swapToken;
    //ITokenSwap public lpToken;
    address payable public finance;
    uint256 public tradingFee;
    bool public paused = false;

    function pause() external onlyOwner  {
        paused = true;
    }

    function unPause() external onlyOwner {
        paused = false;
    }

    constructor () public {
        finance = msg.sender;
        tradingFee = 5000;
    }

    function() external payable {
    }

    function setFinanceAddress(address payable _financeAddress) external onlyOwner returns(bool) {
        finance = _financeAddress;
        return true;
    }

    function setTradingFee(uint256 _value) external onlyOwner returns(bool) {
        tradingFee = _value;
        return true;
    }

    function getBaseInfo() public view returns (address payable, uint256) {
        return (finance, tradingFee);
    }

    function getSwapToken(address lpToken) public view returns(address) {
        return address(ITokenSwap(lpToken).tokenAddress());
    }

    function tokenToTrxSwap(address swapToken, address lpToken, uint256 tokens_sold, uint256 min_trx, address payable userAddress) external returns (uint256) {
        require(!paused, "the contract had been paused");
        require(swapToken == ITokenSwap(lpToken).tokenAddress(), "swapToken and lpToken not matched");
        require(tokens_sold > 0);

        ITRC20(swapToken).safeTransferFrom(msg.sender, address(this), tokens_sold);
        uint256 _value = ITRC20(swapToken).allowance(address(this), address(lpToken));
        if (_value < tokens_sold) {
            ITRC20(swapToken).safeApprove(address(lpToken), uint256(-1));
        }
        return tokenToTrx(swapToken, lpToken, tokens_sold, min_trx, userAddress);
    }

    function tokenToTrx(address swapToken, address lpToken, uint256 tokens_sold, uint256 min_trx, address payable userAddress) private nonReentrant returns (uint256) {
        uint256 _value = ITokenSwap(lpToken).tokenToTrxTransferInput(tokens_sold, min_trx, block.timestamp.add(1800), address(this));
        if (_value == 0) {
            return 0;
        }
        uint256 _a = _value.mul(tradingFee).div(10000);
        uint _b = _value.sub(_a);
        if (_b > 0) {
            address(userAddress).transfer(_b);
        }
        if (_a > 0) {
            address(finance).transfer(_a);
        }
        return _b;
    }


    function rescueTrx(address payable toAddress, uint256 amount) external onlyOwner returns(bool) {
        require(toAddress != address(0) && amount> 0);
        address(toAddress).transfer(amount);
        return true;
    }

    function rescueToken(address toAddress, address token, uint256 amount) external onlyOwner returns(bool) {
        require(toAddress != address(0) && token != address(0) && amount > 0);
        ITRC20(token).transfer(toAddress, amount);
        return true;
    }




}
