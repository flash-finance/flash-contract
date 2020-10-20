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

    address payable public finance;
    uint256 public baseFee = 10000;
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
        tradingFee = 10;
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

    // swap: tokenToTrx
    function tokenToTrxSwap(address swapToken, address lpToken, uint256 tokensSold, uint256 minTrx, address payable userAddress) external returns (uint256) {
        require(!paused, "the contract had been paused");
        require(swapToken == ITokenSwap(lpToken).tokenAddress(), "swapToken and lpToken not matched");
        require(tokensSold > 0 && minTrx > 0);

        ITRC20(swapToken).safeTransferFrom(msg.sender, address(this), tokensSold);
        uint256 _value = ITRC20(swapToken).allowance(address(this), address(lpToken));
        if (_value < tokensSold) {
            ITRC20(swapToken).safeApprove(address(lpToken), uint256(-1));
        }
        return tokenToTrx(swapToken, lpToken, tokensSold, minTrx, userAddress);
    }

    function tokenToTrx(address swapToken, address lpToken, uint256 tokensSold, uint256 minTrx, address payable userAddress) private nonReentrant returns (uint256) {
        uint256 _value = ITokenSwap(lpToken).tokenToTrxTransferInput(tokensSold, minTrx, block.timestamp.add(1800), address(this));
        if (_value == 0) {
            return 0;
        }
        uint256 _a = _value.mul(tradingFee).div(baseFee);
        uint _b = _value.sub(_a);
        if (_b > 0) {
            address(userAddress).transfer(_b);
        }
        if (_a > 0) {
            address(finance).transfer(_a);
        }
        return _b;
    }

    // swap: tokenToToken
    function tokenToTokenSwap(address swapToken, address lpToken, uint256 tokensSold, uint256 minTokensBought, uint256 minTrxBought, address userAddress, address targetToken) external returns (uint256) {
        require(!paused, "the contract had been paused");
        require(swapToken == ITokenSwap(lpToken).tokenAddress(), "swapToken and lpToken not matched");
        require(tokensSold > 0 && minTokensBought > 0 && minTrxBought > 0);

        ITRC20(swapToken).safeTransferFrom(msg.sender, address(this), tokensSold);

        uint256 _value = ITRC20(swapToken).allowance(address(this), address(lpToken));
        if (_value < tokensSold) {
            ITRC20(swapToken).safeApprove(address(lpToken), uint256(-1));
        }

        return tokenToToken(swapToken, lpToken, tokensSold, minTokensBought, minTrxBought, userAddress, targetToken);
    }

    function tokenToToken(address swapToken, address lpToken, uint256 tokensSold, uint256 minTokensBought, uint256 minTrxBought, address userAddress, address targetToken) private nonReentrant  returns (uint256) {
        uint256 _value = ITokenSwap(lpToken).tokenToTokenTransferInput(tokensSold, minTokensBought, minTrxBought, block.timestamp.add(1800), address(this), targetToken);
        if (_value == 0) {
            return 0;
        }
        uint256 _a = _value.mul(tradingFee).div(baseFee);
        uint _b = _value.sub(_a);
        if (_b > 0) {
            ITRC20(targetToken).transfer(userAddress, _b);
        }
        if (_a > 0) {
            ITRC20(targetToken).transfer(finance, _a);
        }

        return _b;
    }

    // swap: trxToToken
    function trxToTokenSwap(address swapToken, address lpToken, uint256 minTokens, address userAddress) external payable returns (uint256) {
        require(!paused, "the contract had been paused");
        require(swapToken == ITokenSwap(lpToken).tokenAddress(), "swapToken and lpToken not matched");
        require(msg.value > 0 && minTokens > 0);

        return trxToToken(swapToken, lpToken, msg.value, minTokens, userAddress);
    }

    function trxToToken(address swapToken, address lpToken, uint256 trxAmounts, uint256 minTokens, address userAddress) private nonReentrant returns (uint256) {
        uint256 _value = ITokenSwap(lpToken).trxToTokenTransferInput.value(trxAmounts)(minTokens, block.timestamp.add(1800), address(this));
        if (_value == 0) {
            return 0;
        }
        uint256 _a = _value.mul(tradingFee).div(baseFee);
        uint _b = _value.sub(_a);
        if (_b > 0) {
            ITRC20(swapToken).transfer(userAddress, _b);
        }
        if (_a > 0) {
            ITRC20(swapToken).transfer(finance, _a);
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
