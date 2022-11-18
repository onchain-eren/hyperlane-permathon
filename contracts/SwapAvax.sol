//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
interface IWAVAX is IERC20 {
        function deposit() external payable;
        function withdraw(uint) external;
}
contract SwapAvax {
    using SafeERC20 for IERC20;

    uint256 MAX_INT = 2**256 - 1;
    address private immutable owner;
    address private immutable executor;

    address constant avalancheOutbox = 0x0761b0827849abbf7b0cC09CE14e1C93D87f5004;

    

    IWAVAX private constant WAVAX = IWAVAX(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    modifier onlyExecutor() {
        require(msg.sender == executor);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() payable {
        owner = msg.sender;
        executor = msg.sender;
    }

    receive() external payable {
    }

    // perform a swap on target exchange from tokenIn to (tokenOut) with _payload, (tokenOut is implicity encoded into _payload)
    function swap(address _target, bytes memory _payload, address tokenIn, uint256 amount_in) external onlyExecutor payable {
        SafeERC20.safeApprove(IERC20(tokenIn), address(_target), amount_in);
        (bool _success, bytes memory _response) = _target.call(_payload);
        require(_success); _response;
    }

    // //withdraw all weth to owner of the contract
    function withdraw() external onlyOwner {
        SafeERC20.safeTransfer(WETH, msg.sender, WETH.balanceOf(address(this)));
    }

    //deposit
    function deposit() external onlyOwner payable {
        WAVAX.deposit{value: msg.value}();
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
