// SPDX-License-Identifier: GPL-3.0
pragma solidity = 0.8.4;

interface TSHDATA {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account, address m_sender) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function increaseAllowance(address spender, uint256 value, address m_sender, uint _type) external returns (bool);
    function decreaseAllowance(address spender, uint256 value, address m_sender, uint _type) external returns (bool);
    function sendLiquid(address from, address to, uint256 amount, address m_sender) external returns (bool);
    function approve(address spender, uint256 amount, address m_sender, uint _type) external returns (bool);
    function mint(address to, uint256 value) external returns (bool);
    function burn(address to, uint256 value) external returns (bool);
    function changeMinter(address newminter) external returns (bool);
    function pauseContract(uint duration) external returns (bool);
}

contract TSH {
    string public name = 'eShilling data';
    string public symbol = 'TSH';
    string  public version = '1';
    uint public decimals = 18;
    uint public totalSupply;
    mapping(address => uint) public balanceOfUser;
    mapping(address => mapping(address => uint)) public allowance;
    mapping(address => bool) public isUser;
    mapping(uint => address[]) public auditAddresses;
    mapping(uint => uint[]) public auditAmounts;
    mapping(uint => uint) public nonceTime;
    uint lastTimestamp;
    uint auditnonce;
    mapping (address => uint) public nonces;
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;
    address[] public users;
    address public minter;
    address public proxy;
    uint public paused;
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);    

    constructor(uint256 chainId_) {
        minter = msg.sender;
        lastTimestamp = block.timestamp;
        nonceTime[auditnonce] = block.timestamp;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId_,
            address(this)
        ));
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
        require (msg.sender == minter);
        require (duration < 2592000);
        paused = block.timestamp + duration;
        return true;
    }

    function mint(address to, uint value) external returns (bool) {
        require (msg.sender == minter);
        require (paused < block.timestamp);
        if(!isUser[to]) {
            isUser[to] = true;
            users.push(to);
        }
        if(block.timestamp + 604800 > lastTimestamp) {
            lastTimestamp = block.timestamp;
            auditnonce += 1;
            nonceTime[auditnonce] = block.timestamp;
        }
        auditAddresses[auditnonce].push(to);
        auditAmounts[auditnonce].push(value);
        totalSupply += value;
        balanceOfUser[to] += value;
        emit Transfer(address(0), to, value);
        return true;
    }

    function burn(address from, uint value) external returns (bool) {
        require (msg.sender == minter);
        require (paused < block.timestamp);
        totalSupply -= value;
        balanceOfUser[from] -= value;
        emit Transfer(from, address(0), value);
        return true;
    }
    
    function balanceOf(address user, address m_sender) public view returns (uint) {
        m_sender = address(0); //Placeholder depending on type of future upgrade
        return balanceOfUser[user];
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        require (paused < block.timestamp);
        if(!isUser[to]) {
            isUser[to] = true;
            users.push(to);
        }
        balanceOfUser[from] -= value;
        balanceOfUser[to] += value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value, address proxyaddy, uint _type) external returns (bool) {
        address m_sender = msg.sender;
        _type = 0;
        if (msg.sender == proxy) {
            m_sender = proxyaddy;
        }
        require(m_sender != address(0));
        _approve(m_sender, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint value, address proxyaddy, uint _type) external returns (bool) {
        address m_sender = msg.sender;
        _type = 0;
        if (msg.sender == proxy) {
            m_sender = proxyaddy;
        }
        require(m_sender != address(0));
        allowance[m_sender][spender] += value;
        emit Approval(m_sender, spender, allowance[m_sender][spender]);
        return true;
    }
    
    function decreaseAllowance(address spender, uint value, address proxyaddy, uint _type) external returns (bool) {
        address m_sender = msg.sender;
        _type = 0;
        if (msg.sender == proxy) {
            m_sender = proxyaddy;
        }
        allowance[m_sender][spender] -= value;
        emit Approval(m_sender, spender, allowance[m_sender][spender]);
        return true;
    }

    function sendLiquid(address from, address to, uint value, address proxyaddy) external returns (bool) {
        address m_sender = msg.sender;
        if (msg.sender == proxy) {
            m_sender = proxyaddy;
        }
        if(from != m_sender) {
            allowance[from][m_sender] -= value;            
        }
        _transfer(from, to, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }
    // --- Approve by signature ---
    function permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01",DOMAIN_SEPARATOR,keccak256(abi.encode(PERMIT_TYPEHASH,holder,spender,nonce,expiry,allowed))));
        require(holder != address(0), "Invalid-address");
        require(holder == ecrecover(digest, v, r, s), "Invalid-permit");
        require(expiry == 0 || block.timestamp <= expiry, "Permit-expired");
        require(nonce == nonces[holder], "Invalid-nonce");
        nonces[holder]+=1;
        uint wad = allowed ? type(uint256).max : 0;
        allowance[holder][spender] = wad;
        emit Approval(holder, spender, wad);
    }
}