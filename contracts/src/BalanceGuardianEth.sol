// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../lib/hyperlane-monorepo/solidity/interfaces/IOutbox.sol";

contract BalanceGuardianEth {
    address constant ethereumOutbox = 0x2f9DB5616fa3fAd1aB06cB2C906830BA63d135e3;

    // record total number of vtoken each user owns on all supported chains
    // user_mainnet_addr to coinbalances (in au)
    mapping(address => mapping(string => uint256)) balances;
    address public admin;
    
    modifier adminOnly {
        require(msg.sender == admin);
        _;
    }

    modifier whitelistOnly {
        require(
            msg.sender == admin 
        || msg.sender == 0x74Ac851230D1A3Ff772A03799183e72B768560DA);
        _;
    }

    event Deposit(address indexed _account, string indexed _token, uint256 _amount);
    event Send(address indexed from, address indexed to, string indexed _token, uint256 _amount); 

    constructor(){
        admin = msg.sender;
    }

    // should be an arr for multiple chain exec, for now just field
    struct CrossChainExecution {
        uint32  destChain; // domain ids of dest chains
        address  destContractAddress; // deployed receipt of msg on dest chains
        uint256  amountIn; // input amount for tokenIn on dest chains
        uint256  expectedAmountOut; // expected output
        address swapTargetAddress; //  execution router contract on dest chains
        bytes payload; // pre-bundled payload for execution
        address fromToken; // fromToken address
    }

    /**
     * swap: check enough virtual balance, call into satellite's contract, do swap on each chain, and update virtual balance based on swap result
     *  */ 
    function swap(
        string calldata fromToken, // virtual from token
        string calldata toToken, // virtual to token
        uint256 total_input, // to remove this, after can receive the amount
        uint256 expected_total_output, // to remove this
        CrossChainExecution calldata info
    ) public payable {
        address sender = msg.sender;
        // check whether user has this much virtual balance
        require(balances[sender][fromToken] >= total_input, "not enough vbalance for swap");
        // call into each dest_chain for execution  
        _send_swap_signal(info.destChain, info.destContractAddress, info.swapTargetAddress, info.payload, info.fromToken, info.amountIn);
        // check the swap result
        
        // update virtual balance    
        balances[sender][fromToken] -= total_input; 
        balances[sender][toToken] += expected_total_output;
    }

    function _send_swap_signal(uint32 chain_domain, address addr, address _target, bytes memory _payload, address _tokenIn, uint256 _amount_in) internal {
        IOutbox(ethereumOutbox).dispatch(
            chain_domain,
            addressToBytes32(addr),
            abi.encode(_target, _payload, _tokenIn, _amount_in)
        );
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

     /**
     * Increment virtual balances based on a payment id
     * todo: add payment_id verification to remove whitelistOnly
     * make on-ramp process permissionless, currently this is only function not permissionless
     */
    function increment_virtual_balances(address account, string calldata token, uint256 amount) external whitelistOnly {
        balances[account][token] += amount;
        emit Deposit(account, token, amount);
    }

    /**
     * Send virutal token to other address
     */
    function send(address to, string calldata token, uint256 amount) external {
        address sender = msg.sender;
        require(balances[sender][token] >= amount, "not enough vbalance for send");
        balances[sender][token] -= amount;
        balances[to][token] += amount;
        emit Send(sender, to, token, amount);
    }

    /**
     * Read only function to retrieve the virtual token balance of a given account.
     */
    function balanceOf(address account, string calldata token) public view returns (uint256) {
        return balances[account][token];
    }
}
