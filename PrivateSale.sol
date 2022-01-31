// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./EarlyToken.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PrivateSale is Ownable, ReentrancyGuard {
    address public investToken;
    address public fundsReceiver;
    EarlyToken public eToken;
    uint256 public price;
    uint256 public priceQuote;
    uint256 public initialCap;
    uint256 public maxCap;
    uint256 public totalraiseCap;
    uint256 public totalraised;
    uint256 public totalissued;
    uint256 public startTime;
    uint256 public duration;
    uint256 public epochTime;
    uint256 public endTime;
    bool public saleEnabled;
    uint256 public mininvest;
    uint256 public numWhitelisted = 0;
    uint256 public numInvested = 0;

    event SaleEnabled(bool enabled, uint256 time);
    event Invested(address investor, uint256 amount);

    struct InvestorInfo {
        uint256 amountInvested;
        bool claimed;
    }

    mapping(address => bool) public whitelisted;

    mapping(address => InvestorInfo) public investorInfoMap;

    constructor(
        address _investToken,
        uint256 _startTime,
        uint256 _duration,
        uint256 _epochTime,
        uint256 _initialCap,
        uint256 _totalraiseCap,
        uint256 _minInvest,
        uint256 _price,
        uint256 _priceQuote,
        uint256 _maxCap,
        address _fundsReceiver,
        EarlyToken _eToken
    ) {
        investToken = _investToken;
        startTime = _startTime;
        duration = _duration;
        epochTime = _epochTime;
        initialCap = _initialCap;
        totalraiseCap = _totalraiseCap;
        mininvest = _minInvest;
        require(duration < 7 days, "DURATION_TOO_LONG");
        endTime = startTime + duration;
        eToken = _eToken;
        saleEnabled = false;
        price = _price;
        priceQuote = _priceQuote;
        fundsReceiver = _fundsReceiver;
        maxCap = _maxCap;
    }

    function setStartTimeAndDuration(uint256 _startTime, uint256 _duration)
        external
        onlyOwner
    {
        startTime = _startTime;
        duration = _duration;
        endTime = _startTime + _duration;
    }

    function whitelist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelisted[_addresses[i]] = true;
            numWhitelisted += 1;
        }
    }

    function unwhitelist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelisted[_addresses[i]] = false;
            numWhitelisted -= 1;
        }
    }

    function currentEpoch() public view returns (uint256) {
        if (block.timestamp > startTime) {
            return (block.timestamp - startTime) / epochTime;
        } else {
            return 0;
        }
    }

    function currentCap() public view returns (uint256) {
        uint256 epochs = currentEpoch();

        // protect overflow for next computation 2**epochs
        if(epochs > 10){
            epochs = 10;
        }

        uint256 cap = initialCap * (2**epochs);
        if (cap > maxCap) {
            return maxCap;
        } else {
            return cap;
        }
    }

    function invest(uint256 investAmount) public nonReentrant {
        require(block.timestamp >= startTime, "SALE_NOT_STARTED");
        require(saleEnabled, "SALE_NOT_ENABLED");
        require(whitelisted[msg.sender] == true, "NOT_WHITELISTED");
        require(
            totalraised + investAmount <= totalraiseCap,
            "ABOVE_RAISE_LIMIT"
        );
        require(block.timestamp <= endTime, "SALE_FINISHED");

        uint256 xcap = currentCap();

        InvestorInfo storage investor = investorInfoMap[msg.sender];

        require(
            investor.amountInvested + investAmount >= mininvest,
            "BELOW_INVEST_TOKEN_AMOUNT"
        );
        require(
            investor.amountInvested + investAmount <= xcap,
            "ABOVE_MAX_CONTRIBUTION"
        );

        require(
            ERC20(investToken).transferFrom(
                msg.sender,
                address(this),
                investAmount
            ),
            "TRANSFER_FAILED"
        );

        uint256 issueAmount = (investAmount *
            priceQuote *
            10**eToken.decimals()) /
            (price * 10**ERC20(investToken).decimals());

        eToken.issue(msg.sender, issueAmount);

        totalraised += investAmount;
        totalissued += issueAmount;
        if (investor.amountInvested == 0) {
            numInvested += 1;
        }
        investor.amountInvested += investAmount;

        emit Invested(msg.sender, investAmount);
    }

    function transferFundsToReceiver(uint256 amount) public onlyOwner {
        require(block.timestamp > endTime, "SALE_NOT_FINISHED");
        require(
            ERC20(investToken).transfer(fundsReceiver, amount),
            "TRANSFER_FAILED"
        );
    }

    function enableSale() public onlyOwner {
        saleEnabled = true;
        emit SaleEnabled(true, block.timestamp);
    }
}
