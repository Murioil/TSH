// SPDX-License-Identifier: GPL-3.0
pragma solidity = 0.8.4;

//WARNING: Do not assume this coin will operate the same with most standard contracts!
//This has an IERC20 interface but this is a completely revolutionary kind of coin with a variable supply.
interface TSH {
    function decimals() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function increaseAllowance(address spender, uint value) external returns (bool);
    function decreaseAllowance(address spender, uint value) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract CTSH is TSH {
    // --- ERC20 Data ---
    string public constant name     = "eShilling";
    string public constant symbol   = "TSH";
    string public version  = "1";
    
    event Approval(address indexed from, address indexed to, uint amount);
    event Transfer(address indexed from, address indexed to, uint amount);
    
    address public minter;
    address public proxy; //Where all the coin functions and storage are
    address public LiquidityPool;
    address public lockpair; //An exception to not revert a temporary reentry

    uint public proxylock;
    
    constructor() {
        minter = msg.sender;
    }

    function changeMinter(address newminter) public {
        require(msg.sender == minter);
        minter = newminter;
    }    

    function setProxy(address prox) public {
        require(block.timestamp > proxylock);
        require(msg.sender == minter);
        proxy = prox;
    }

    function setLiquidityPool(address prox) public {
        require(block.timestamp > proxylock);
        require(msg.sender == minter);
        LiquidityPool = prox;
    }

    function lockProxies(uint locktime) public returns (bool) {
        require(msg.sender == minter);
        proxylock = block.timestamp + locktime;
        return true;
    }

    function lockthis(address pair) public returns (bool) {
        require(msg.sender == LiquidityPool);
        lockpair = pair;
        return true;
    }
    
    //ERC20 Functions
    //Note: Solidity does not allow spaces between parameters in abi function calls
    function decimals() public virtual override view returns (uint) {
        bool success;
        bytes memory result;
        (success, result) = proxy.staticcall(abi.encodeWithSignature("decimals()"));
        require(success);
        uint _decimals = abi.decode(result, (uint));
        return _decimals;
    }

    function totalSupply() public virtual override view returns (uint) {
        bool success;
        bytes memory result;
        (success, result) = proxy.staticcall(abi.encodeWithSignature("totalSupply()"));
        require(success);
        uint _totalSupply = abi.decode(result, (uint));
        return _totalSupply;
    }

    function balanceOf(address user) public virtual override view returns (uint) {
        bool success;
        bytes memory result;
        (success, result) = proxy.staticcall(abi.encodeWithSignature("balanceOf(address,address)",user,msg.sender));
        require(success);
        uint liquid = abi.decode(result, (uint));
        return liquid;
    }
    
    function allowance(address owner, address spender) public virtual override view returns (uint) {
        bool success;
        bytes memory result;
        (success, result) = proxy.staticcall(abi.encodeWithSignature("allowance(address,address)",owner,spender));
        require(success);
        return abi.decode(result, (uint));
    }
    
    function approve(address spender, uint value) public virtual override returns (bool) {
        require(spender != address(0));
        bool success;
        bytes memory result;
        (success, result) = proxy.call(abi.encodeWithSignature("approve(address,uint256,address,uint256)",spender,value,msg.sender,0));
        require(success);
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function increaseAllowance(address spender, uint value) public virtual override returns (bool) {
        require(spender != address(0));
        bool success;
        bytes memory result;
        (success, result) = proxy.call(abi.encodeWithSignature("increaseAllowance(address,uint256,address,uint256)",spender,value,msg.sender,0));
        require(success); 
        emit Approval(msg.sender, spender, allowance(msg.sender, spender));
        return true;
    }
    
    function decreaseAllowance(address spender, uint value) public virtual override returns (bool) {
        require(spender != address(0));
        bool success;
        bytes memory result;
        (success, result) = proxy.call(abi.encodeWithSignature("decreaseAllowance(address,uint256,address,uint256)",spender,value,msg.sender,0));
        require(success); 
        emit Approval(msg.sender, spender, allowance(msg.sender, spender));
        return true;
    }
    
    function transfer(address to, uint value) public virtual override returns (bool) {
        if(msg.sender == lockpair) {
            lockpair = address(0);
            return true;
        }
        bool success;
        bytes memory result;
        (success, result) = proxy.call(abi.encodeWithSignature("sendLiquid(address,address,uint256,address)",msg.sender,to,value,msg.sender));
        require(success);
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value) public virtual override returns (bool) {
        if(msg.sender == lockpair) {
            lockpair = address(0);
            return true;
        }
        bool success;
        bytes memory result;
        (success, result) = proxy.call(abi.encodeWithSignature("sendLiquid(address,address,uint256,address)",from,to,value,msg.sender));
        require(success);
        emit Transfer(from, to, value);
        return true;
    }
}