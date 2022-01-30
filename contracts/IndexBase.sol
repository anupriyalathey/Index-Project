// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//for tokens which do not follow erc20 standard otherwise bug and revert
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//Helper contract - 
interface IUniswapV2Router02 {
    function WETH() external pure returns (address);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract IndexBase is ERC20 {
    //safeERC's function also in erc20
    using SafeERC20 for IERC20;

    IERC20 public usdt;
    IERC20[2] public underlying;

    //can be set only once in constructor only so cheaper
    uint256 immutable count;

    IUniswapV2Router02 uniRouter;
    IERC20 weth;
    
    constructor(IERC20 _usdt, IERC20[2] memory _underlying, IUniswapV2Router02 _uniRouter) ERC20("Index", "IDX") {
        usdt = _usdt;
        underlying = _underlying;

        count = _underlying.length;

        uniRouter = _uniRouter;
        weth = IERC20(uniRouter.WETH());
    }

    // deposit usdt
    // requires user to approve usdt beforehand
    function deposit(uint256 amountIn) external {
        usdt.safeTransferFrom(msg.sender, address(this), amountIn);

        _swap(amountIn);

        _mint(msg.sender, amountIn);
    }

    function withdraw(uint256 amountToBurn) external {
        uint256 currentSupply = totalSupply();

        // burn user's Index tokens
        _burn(msg.sender, amountToBurn);

        // transfer proportional underlying tokens to the user
        for(uint256 i=0; i<count; i++) {
            uint256 underlyingBalance = underlying[i].balanceOf(address(this));
            uint256 underlyingToTransfer = underlyingBalance * amountToBurn / currentSupply;
            underlying[i].safeTransfer(msg.sender, underlyingToTransfer);
        }
    }

    function _swap(uint256 amountIn) internal {
        uint256 amountForEachSwap = amountIn / count;

        usdt.safeApprove(address(uniRouter), amountIn);
        for(uint256 i=0; i<count; i++) {
            _swapUSDTToUnderlying(amountForEachSwap, underlying[i]);
        }
    }

    function _swapUSDTToUnderlying(uint256 _usdtAmount, IERC20 _underlying) internal {
        address[] memory path = new address[](3);
        path[0] = address(usdt);
        path[1] = address(weth); //used weth since pools with it common, generally have more liquidity
        path[2] = address(_underlying);

        uniRouter.swapExactTokensForTokens(
            _usdtAmount,
            0, //TODO: set amount out
            path,
            address(this),
            block.timestamp
        );
    }
}