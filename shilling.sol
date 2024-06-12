// SPDX-License-Identifier: GPL-3.0
pragma solidity = 0.8.4;

interface TSHDATA {
    function totalSupply() external view returns (uint80);
    function balanceOf(address account, address m_sender) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint80);
    function increaseAllowance(address spender, uint256 value, address m_sender, uint8 _type) external returns (bool);
    function decreaseAllowance(address spender, uint256 value, address m_sender, uint8 _type) external returns (bool);
    function sendLiquid(address from, address to, uint256 amount, address m_sender) external returns (bool);
    function approve(address spender, uint256 amount, address m_sender, uint8 _type) external returns (bool);
    function mint(address to, uint256 value) external returns (bool);
    function burn(address to, uint256 value) external returns (bool);
    function changeMinter(address newminter) external returns (bool);
    function pauseContract(uint256 duration) external returns (bool);
}

contract TSH {
    string public name = 'eShilling data';
    string public symbol = 'TSH';
    string  public version = '1';
    uint8 public decimals = 8;
    uint80 public totalSupply;
    mapping(address => uint80) public balanceOfUser;
    mapping(address => mapping(address => uint80)) public allowance;
    mapping(address => bool) public isUser;
    mapping(uint => address[]) public auditAddresses;
    mapping(uint => uint80[]) public auditAmounts;
    mapping(uint => address[]) public auditAddresses2;
    mapping(uint => uint80[]) public auditAmounts2;
    mapping(uint => uint) public nonceTime;
    uint public lastTimestamp;
    uint public auditnonce;
    address[] public users;
    address public minter;
    address public proxy;
    uint public paused;
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor() {
        minter = msg.sender;
    }
    
    function safeConvert(uint256 data) internal pure returns (uint80) {
        if(data > type(uint80).max) {
            data = type(uint80).max;
        }
        return uint80(data);
    }
    function changeMinter(address newminter) external returns (bool) {
        require (msg.sender == minter);
        minter = newminter;
        return true;
    }
    function setProxy(address newproxy) external returns (bool) {
        require (proxy == address(0));
        require (msg.sender == minter);
        proxy = newproxy;
        return true;
    }
    function pauseContract(uint duration) external returns (bool) {
        if(msg.sender == proxy || paused == type(uint256).max) {
            paused = type(uint256).max;
            return true;
        }
        require (msg.sender == minter);
        require (duration < 2592000);
        paused = block.timestamp + duration;
        return true;
    }
    function getLen(uint8 which, uint thenonce) public view returns (uint mylen) {
        if(which == 0) {
            return users.length;
        }
        if(which == 1) {
            return auditAddresses[thenonce].length;
        }
        if(which == 2) {
            return auditAddresses2[thenonce].length;
        }
    }
    function mint(address to, uint value) external returns (bool) {
        require (msg.sender == minter);
        require (paused < block.timestamp);
        uint80 newvalue = safeConvert(value);
        if(!isUser[to]) {
            isUser[to] = true;
            users.push(to);
        }
        if(block.timestamp > lastTimestamp) {
            lastTimestamp = block.timestamp + 604800;
            auditnonce += 1;
            nonceTime[auditnonce] = block.timestamp;
        }
        auditAddresses[auditnonce].push(to);
        auditAmounts[auditnonce].push(newvalue);
        totalSupply += newvalue;
        balanceOfUser[to] += newvalue;
        emit Transfer(address(0), to, uint(newvalue));
        return true;
    }
    function burn(address from, uint value) external returns (bool) {
        require (msg.sender == minter);
        require (paused < block.timestamp);
        require (from == minter);
        uint80 newvalue = safeConvert(value);
        if(block.timestamp > lastTimestamp) {
            lastTimestamp = block.timestamp + 604800;
            auditnonce += 1;
            nonceTime[auditnonce] = block.timestamp;
        }
        auditAddresses2[auditnonce].push(from);
        auditAmounts2[auditnonce].push(newvalue);
        totalSupply -= newvalue;
        balanceOfUser[from] -= newvalue;
        emit Transfer(from, address(0), uint(newvalue));
        return true;
    }
    function balanceOf(address user, address m_sender) public view returns (uint) {
        m_sender = address(0); //Placeholder depending on type of future upgrade
        return uint(balanceOfUser[user]);
    }
    function _approve(address owner, address spender, uint value) private {
        uint80 newvalue = safeConvert(value);
        allowance[owner][spender] = newvalue;
        emit Approval(owner, spender, uint(newvalue));
    }
    function _transfer(address from, address to, uint value) private {
        require (paused < block.timestamp);
        uint80 newvalue = safeConvert(value);
        if(!isUser[to]) {
            isUser[to] = true;
            users.push(to);
        }
        balanceOfUser[from] -= newvalue;
        balanceOfUser[to] += newvalue;
        emit Transfer(from, to, uint(newvalue));
    }
    function approve(address spender, uint value, address proxyaddy, uint8 _type) external returns (bool) {
        address m_sender = msg.sender;
        _type = 0;
        if (msg.sender == proxy) {
            m_sender = proxyaddy;
        }
        require(m_sender != address(0));
        _approve(m_sender, spender, value);
        return true;
    }
    function increaseAllowance(address spender, uint value, address proxyaddy, uint8 _type) external returns (bool) {
        address m_sender = msg.sender;
        _type = 0;
        if (msg.sender == proxy) {
            m_sender = proxyaddy;
        }
        require(m_sender != address(0));
        allowance[m_sender][spender] += safeConvert(value);
        emit Approval(m_sender, spender, uint(allowance[m_sender][spender]));
        return true;
    }    
    function decreaseAllowance(address spender, uint value, address proxyaddy, uint8 _type) external returns (bool) {
        address m_sender = msg.sender;
        _type = 0;
        if (msg.sender == proxy) {
            m_sender = proxyaddy;
        }
        require(m_sender != address(0));        
        allowance[m_sender][spender] -= safeConvert(value);
        emit Approval(m_sender, spender, uint(allowance[m_sender][spender]));
        return true;
    }
    function sendLiquid(address from, address to, uint value, address proxyaddy) external returns (bool) {
        address m_sender = msg.sender;
        if (msg.sender == proxy) {
            m_sender = proxyaddy;
        }
        if(from != m_sender) {
            allowance[from][m_sender] -= safeConvert(value);
        }
        _transfer(from, to, value);
        return true;
    }
    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    function transferFrom(address from, address to, uint value) external returns (bool) {
        allowance[from][msg.sender] -= safeConvert(value);
        _transfer(from, to, value);
        return true;
    }
}