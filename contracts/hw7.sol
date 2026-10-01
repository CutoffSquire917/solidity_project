// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 1.
abstract contract BalanceBook {
    mapping(address => uint256) internal _balances;
    uint256 internal _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0) && to != address(0), "Zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Zero address");
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract StableCoin is BalanceBook {
    string public constant name = "Treasury Stable Coin";
    string public constant symbol = "TSC";
    uint8 public constant decimals = 18;
    uint256 public constant FEE_PERCENT = 1;

    address public owner;
    address public treasury;

    event TreasuryFeeCollected(
        address indexed from,
        address indexed treasury,
        uint256 fee
    );
    event TreasuryChanged(address indexed newTreasury);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address treasury_, uint256 initialSupply) {
        require(treasury_ != address(0), "Zero treasury");
        owner = msg.sender;
        treasury = treasury_;
        _mint(msg.sender, initialSupply);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Zero treasury");
        treasury = newTreasury;
        emit TreasuryChanged(newTreasury);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0) && to != address(0), "Zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        uint256 fee = (amount * FEE_PERCENT) / 100;
        uint256 received = amount - fee;
        _balances[from] -= amount;
        _balances[to] += received;
        emit Transfer(from, to, received);
        if (fee > 0) {
            _balances[treasury] += fee;
            emit Transfer(from, treasury, fee);
            emit TreasuryFeeCollected(from, treasury, fee);
        }
    }
}

// 2.
contract Teacher {
    function role() public pure virtual returns (string memory) {
        return "Teacher";
    }
}

contract Mentor {
    function role() public pure virtual returns (string memory) {
        return "Mentor";
    }
}

contract Professor is Teacher, Mentor {
    function role()
        public
        pure
        override(Teacher, Mentor)
        returns (string memory)
    {
        return "Professor";
    }

    function baseRole() public pure returns (string memory) {
        return super.role();
    }

    function teacherRole() public pure returns (string memory) {
        return Teacher.role();
    }

    function mentorRole() public pure returns (string memory) {
        return Mentor.role();
    }
}

// 3.
interface IVault {
    function deposit(address user) external payable;
    function withdraw(address user, uint256 amount) external;
    function balanceOf(address user) external view returns (uint256);
}

contract Vault is IVault {
    address public owner;
    address public broker;
    mapping(address => uint256) private _balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event BrokerSet(address indexed broker);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyBroker() {
        require(msg.sender == broker, "Only broker");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setBroker(address broker_) external onlyOwner {
        require(broker_ != address(0), "Zero address");
        broker = broker_;
        emit BrokerSet(broker_);
    }

    function deposit(address user) external payable onlyBroker {
        require(msg.value > 0, "Zero amount");
        _balances[user] += msg.value;
        emit Deposited(user, msg.value);
    }

    function withdraw(address user, uint256 amount) external onlyBroker {
        require(amount > 0, "Zero amount");
        require(_balances[user] >= amount, "Insufficient balance");
        _balances[user] -= amount;
        (bool ok, ) = user.call{value: amount}("");
        require(ok, "Transfer failed");
        emit Withdrawn(user, amount);
    }

    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }
}

contract Broker {
    IVault public immutable vault;

    event ForwardedDeposit(address indexed user, uint256 amount);
    event ForwardedWithdraw(address indexed user, uint256 amount);

    constructor(address vault_) {
        require(vault_ != address(0), "Zero address");
        vault = IVault(vault_);
    }

    function deposit() external payable {
        vault.deposit{value: msg.value}(msg.sender);
        emit ForwardedDeposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        vault.withdraw(msg.sender, amount);
        emit ForwardedWithdraw(msg.sender, amount);
    }

    function myBalance() external view returns (uint256) {
        return vault.balanceOf(msg.sender);
    }
}
