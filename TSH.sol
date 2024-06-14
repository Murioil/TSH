// SPDX-License-Identifier: GPL-3.0
pragma solidity = 0.8.4;

//WARNING: Do not assume this coin will operate the same with most standard contracts!
//This has an IERC20 interface but this is a completely revolutionary kind of coin with a variable supply.
interface TSH {
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface TSHDATA {
    function totalSupply() external view returns (uint80);
    function pauseContract(uint256 duration) external returns (bool);
    function balanceOf(address user, address m_sender) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint80);
    function approve(address spender, uint256 value, address proxyaddy, uint8 _type) external returns (bool);
    function sendLiquid(address from, address to, uint256 value, address msg_sender) external returns (bool);
}

contract CTSH is TSH {
    // --- ERC20 Data ---
    string public constant name     = "eShilling";
    string public constant symbol   = "TSH";
    string public version  = "1";
    uint8 public override decimals = 8;
       
    address public minter;
    address public proxy; //Where all the coin functions and storage are
    address public proposedProxy;
    uint public proxylock;
    event Approval(address indexed from, address indexed to, uint amount);
    event Transfer(address indexed from, address indexed to, uint amount);

    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public DOMAIN_SEPARATOR;
    mapping (address => uint) public nonces;
    
    constructor(uint256 chainId_) {
        minter = msg.sender;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId_,
            address(this)
        ));
    }

    function changeMinter(address newminter) public {
        require(msg.sender == minter);
        minter = newminter;
    }
    function setProxy(address prox) public {
        require(msg.sender == minter);
        if(proxy == address(0)) {
            proxy = prox;
            return;
        } else {
            if(proposedProxy != address(0)) {
                require(block.timestamp > proxylock);
                uint thetime = type(uint).max;
                proxylock = thetime;
                TSHDATA(proxy).pauseContract(thetime);
                proxy = proposedProxy;
                return;
            }
        }
        require(proposedProxy == address(0));
        proposedProxy = prox;
        proxylock = block.timestamp + 2592000;
    }
    //ERC20 Functions
    //Note: Solidity does not allow spaces between parameters in abi function calls
    function totalSupply() public virtual override view returns (uint) {
        uint _totalSupply = uint(TSHDATA(proxy).totalSupply());
        return _totalSupply;
    }
    function balanceOf(address user) public virtual override view returns (uint) {
        uint liquid = uint(TSHDATA(proxy).balanceOf(user, msg.sender));
        return liquid;
    }
    function allowance(address owner, address spender) public virtual override view returns (uint) {
        uint _allowance = TSHDATA(proxy).allowance(owner, spender);
        return _allowance;
    }
    function approve(address spender, uint value) public virtual override returns (bool) {
        require(spender != address(0));
        TSHDATA(proxy).approve(spender, value, msg.sender, 0);
        emit Approval(msg.sender, spender, value);
        return true;
    } 
    function transfer(address to, uint value) public virtual override returns (bool) {
        TSHDATA(proxy).sendLiquid(msg.sender, to, value, msg.sender);
        emit Transfer(msg.sender, to, value);
        return true;
    }
    function transferFrom(address from, address to, uint value) public virtual override returns (bool) {
        TSHDATA(proxy).sendLiquid(from, to, value, msg.sender);
        emit Transfer(from, to, value);
        return true;
    }
    // --- Approve by signature ---
    function permit(address holder, address spender, uint256 value, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01",DOMAIN_SEPARATOR,keccak256(abi.encode(PERMIT_TYPEHASH,holder,spender,value,nonces[holder],expiry))));
        require(holder != address(0), "Invalid-address");
        require(holder == ecrecover(digest, v, r, s), "Invalid-permit");
        require(expiry == 0 || block.timestamp <= expiry, "Permit-expired");
        require(spender != address(0));
        nonces[holder]+=1;
        TSHDATA(proxy).approve(spender, value, holder, 0);
        emit Approval(holder, spender, value);
    }
}