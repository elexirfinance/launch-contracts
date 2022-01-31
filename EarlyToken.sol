// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract EarlyToken is AccessControl {
    uint256 private _issuedAmount;
    uint256 private _totalSupply;
    uint256 private _decimals;
    string private _symbol;

    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    event Issued(address account, uint256 amount);
    event Redeemed(address account, uint256 amount);

    // Roles
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    constructor(string memory __symbol, uint256 __decimals) {
        _symbol = __symbol;
        _decimals = __decimals;
        _issuedAmount = 0;
        _totalSupply = 0;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier roleOnly(bytes32 role) {
        require(hasRole(role, _msgSender()));
        _;
    }

    function issue(address account, uint256 amount) public roleOnly(ISSUER_ROLE) {
        require(account != address(0), "zero address");

        _issuedAmount = _issuedAmount.add(amount);
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);

        emit Issued(account, amount);
    }

    // ths token is called be the EarlyTokenRedeemer contract
    function redeem(address account, uint256 amount) public roleOnly(ISSUER_ROLE) {
        require(account != address(0), "zero address");
        require(_balances[account] >= amount, "Insufficent balance");

        _balances[account] = _balances[account].sub(amount);
        _totalSupply = _totalSupply.sub(amount);

        emit Redeemed(account, amount);
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    function issuedAmount() public view returns (uint256) {
        return _issuedAmount;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
}
