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
}

contract TokenSwap is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using TransferHelper for address;

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
        tradingFee = 10;
    }

    function setTokenAddress(address _swapToken, address _lpToken) public onlyOwner {
        swapToken = ITRC20(_swapToken);
        lpToken = ITokenSwap(_lpToken);
    }

    function setFinanceAddress(address payable _financeAddress) public onlyOwner returns(bool) {
        finance = _financeAddress;
        return true;
    }

    function setTradingFee(uint256 _value) public onlyOwner returns(bool) {
        tradingFee = _value;
        return true;
    }

    function getBaseInfo() public view returns (address, address, address payable, uint256) {
        return (address(swapToken), address(lpToken), finance, tradingFee);
    }


    function tokenToTrxSwap(uint256 tokens_sold, uint256 min_trx, address payable userAddress) public  returns (uint256) {

        require(!paused, "the contract had been paused");
        require(address(swapToken).safeTransfer(address(this), tokens_sold), "safeTransfer error");

        uint256 _value = swapToken.allowance(address(this), address(lpToken));
        if (_value < tokens_sold) {
            require(address(swapToken).safeApprove(address(lpToken), uint256(-1)), "safeApprove error");
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

    function tokenToTokenSwap(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_trx_bought, address userAddress, address token_addr) public returns (uint256) {

        require(!paused, "the contract had been paused");
        require(address(swapToken).safeTransfer(address(this), tokens_sold), "safeTransfer error");

        uint256 _value = swapToken.allowance(address(this), address(lpToken));
        if (_value < tokens_sold) {
            require(address(swapToken).safeApprove(address(lpToken), uint256(- 1)), "safeApprove error");
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
            require(address(ITRC20(token_addr)).safeTransfer(userAddress, _b), "tokenAddress safeTransfer error");
        }
        if (_a > 0) {
            require(address(ITRC20(token_addr)).safeTransfer(finance, _a), "tokenAddress safeTransfer error");
        }

        return _b;
    }


}