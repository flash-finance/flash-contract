pragma solidity ^0.5.8;


import "./Common.sol";


interface IJustSwap {

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
}

contract TokenSwap is Ownable {
    using SafeMath for uint256;
    using SafeTRC20 for ITRC20;

    ITRC20 public swapToken;
    IJustSwap public lpToken;
    address public finance;
    uint256 public tradingFee;

    constructor (address _swapTokenAddress, address _lpTokenAddress) internal {
        swapToken = ITRC20(_swapTokenAddress);
        lpToken = IJustSwap(_lpTokenAddress);
        finance = msg.sender;
        tradingFee = 10;
    }

    function setTokenAddress(address _swapTokenAddress, address _lpTokenAddress) public onlyOwner {
        swapToken = ITRC20(_swapTokenAddress);
        lpToken = IJustSwap(_lpTokenAddress);
    }

    function setFinanceAddress(address _financeAddress) public onlyOwner returns(bool) {
        finance = _financeAddress;
        return true;
    }

    function setTradingFee(uint256 _value) public onlyOwner returns(bool) {
        tradingFee = _value;
        return true;
    }

    function getBaseInfo() public view returns (address, address, uint256, uint256) {
        return (swapToken, lpToken, finance, tradingFee);
    }


    function tokenToTrxSwap(uint256 tokens_sold, uint256 min_trx, address userAddress) public whenNotPaused returns (uint256) {
        require(swapToken.safeTransfer(address(this), tokens_sold));

        uint256 _value = swapToken.allowance(address(this), lpToken);
        if (_value < tokens_sold) {
            require(swapToken.safeApprove(lpToken, uint256(-1)));
        }

        return tokenToTrx(tokens_sold, min_trx, userAddress);
    }

    function tokenToTrx(uint256 tokens_sold, uint256 min_trx, address userAddress) private nonReentrant returns (uint256) {
        uint256 _value = lpToken.tokenToTrxTransferInput(tokens_sold, min_trx, block.timestamp.add(1800), address(this));
        if (_value == 0) {
            return 0;
        }

        uint256 _a = _value.mul(_tradingFee).div(10000);
        uint _b = _value.sub(_a);
        if (_b > 0) {
            address(userAddress).transfer(_b);
        }
        if (_a > 0) {
            address(_finance).transfer(_a);
        }

        return _b;
    }

    function tokenToTokenSwap(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_trx_bought, address userAddress, address token_addr) public whenNotPause returns (uint256) {
        require(swapToken.safeTransfer(address(this), tokens_sold));

        uint256 _value = swapToken.allowance(address(this), lpToken);
        if (_value < tokens_sold) {
            require(swapToken.safeApprove(lpToken, uint256(- 1)));
        }

        return tokenToToken(tokens_sold, min_tokens_bought, min_trx_bought, userAddress, token_addr);
    }

    function tokenToToken(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_trx_bought, address userAddress, address token_addr) private nonReentrant  returns (uint256) {
        require(swapToken.safeTransfer(address(this), tokens_sold));

        uint256 _value = swapToken.allowance(address(this), lpToken);
        if (_value < tokens_sold) {
            require(swapToken.safeApprove(lpToken, uint256(- 1)));
        }

        uint256 _value = lpToken.tokenToTokenTransferInput(tokens_sold, min_tokens_bought, min_trx_bought, block.timestamp.add(1800), address(this), token_addr);
        if (_value == 0) {
            return 0;
        }

        uint256 _a = _value.mul(_tradingFee).div(10000);
        uint _b = _value.sub(_a);
        if (_b > 0) {
            ITRC20(token_addr).safeTransfer(userAddress, _b);
        }
        if (_a > 0) {
            ITRC20(token_addr).safeTransfer(finance, _a);
        }

        return _b;
    }


}
