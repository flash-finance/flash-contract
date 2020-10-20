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
}

contract OneTokenSwap is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeTRC20 for ITRC20;

    ITRC20 public swapToken;
    ITokenSwap public lpToken;
    address payable public finance;
    uint256 public tradingFee;
    bool public paused = false;

    function pause() external onlyOwner  {
        paused = true;
    }

    function unPause() external onlyOwner {
        paused = false;
    }

    constructor (address _swapToken, address _lpToken) public {
        swapToken = ITRC20(_swapToken);
        lpToken = ITokenSwap(_lpToken);
        finance = msg.sender;
        tradingFee = 5000;
    }

    function() external payable {
    }

    function setTokenAddress(address _swapToken, address _lpToken) external onlyOwner {
        swapToken = ITRC20(_swapToken);
        lpToken = ITokenSwap(_lpToken);
    }

    function setFinanceAddress(address payable _financeAddress) external onlyOwner returns(bool) {
        finance = _financeAddress;
        return true;
    }

    function setTradingFee(uint256 _value) external onlyOwner returns(bool) {
        tradingFee = _value;
        return true;
    }

    function getBaseInfo() public view returns (address, address, address payable, uint256) {
        return (address(swapToken), address(lpToken), finance, tradingFee);
    }


    function tokenToTrxSwap(uint256 tokens_sold, uint256 min_trx, address payable userAddress) external returns (uint256) {
        require(!paused, "the contract had been paused");
        require(tokens_sold > 0);
        swapToken.safeTransferFrom(msg.sender, address(this), tokens_sold);
        uint256 _value = swapToken.allowance(address(this), address(lpToken));
        if (_value < tokens_sold) {
            swapToken.safeApprove(address(lpToken), uint256(-1));
        }
        return tokenToTrx(tokens_sold, min_trx, userAddress);
    }

    function tokenToTrx(uint256 tokens_sold, uint256 min_trx, address payable userAddress) private nonReentrant returns (uint256) {
        uint256 _value = lpToken.tokenToTrxTransferInput(tokens_sold, min_trx, block.timestamp.add(1800), address(this));
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

    function tokenToTokenSwap(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_trx_bought, address userAddress, address token_addr) external returns (uint256) {
        require(!paused, "the contract had been paused");
        require(tokens_sold > 0);
        swapToken.safeTransferFrom(msg.sender, address(this), tokens_sold);

        uint256 _value = swapToken.allowance(address(this), address(lpToken));
        if (_value < tokens_sold) {
            swapToken.safeApprove(address(lpToken), uint256(-1));
        }

        return tokenToToken(tokens_sold, min_tokens_bought, min_trx_bought, userAddress, token_addr);
    }

    function tokenToToken(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_trx_bought, address userAddress, address token_addr) private nonReentrant  returns (uint256) {
        uint256 _value = lpToken.tokenToTokenTransferInput(tokens_sold, min_tokens_bought, min_trx_bought, block.timestamp.add(1800), address(this), token_addr);
        if (_value == 0) {
            return 0;
        }
        uint256 _a = _value.mul(tradingFee).div(10000);
        uint _b = _value.sub(_a);
        if (_b > 0) {
            ITRC20(token_addr).transfer(userAddress, _b);
        }
        if (_a > 0) {
            ITRC20(token_addr).transfer(finance, _a);
        }

        return _b;
    }


    function trxToTokenSwap(uint256 min_tokens, address userAddress) external payable returns (uint256) {
        require(!paused, "the contract had been paused");
        require(msg.value > 0);
        return trxToToken(msg.value, min_tokens, userAddress);
    }

    function trxToToken(uint256 trx_amounts, uint256 min_tokens, address userAddress) private nonReentrant returns (uint256) {
        uint256 _value = lpToken.trxToTokenTransferInput.value(trx_amounts)(min_tokens, block.timestamp.add(1800), address(this));
        if (_value == 0) {
            return 0;
        }
        uint256 _a = _value.mul(tradingFee).div(10000);
        uint _b = _value.sub(_a);
        if (_b > 0) {
            swapToken.transfer(userAddress, _b);
        }
        if (_a > 0) {
            swapToken.transfer(finance, _a);
        }
        return _b;
    }

}
