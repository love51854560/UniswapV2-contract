// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SimpleUniswapV2Pair.sol";
import "./SimpleUniswapV2Factory.sol";

/**
 * @title SimpleUniswapV2Router
 * @dev A router for interacting with SimpleUniswapV2 pairs
 * This is a simplified version of Uniswap V2 Router with core functionality
 */
contract SimpleUniswapV2Router {
    address public immutable factory;
    
    // Used for safe math operations
    uint private constant _UINT_MAX = type(uint).max;
    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "SimpleUniswapV2Router: EXPIRED");
        _;
    }
    
    constructor(address _factory) {
        require(_factory != address(0), "SimpleUniswapV2Router: FACTORY_ZERO_ADDRESS");
        factory = _factory;
    }
    
    /**
     * @dev Sorts two tokens by address
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "SimpleUniswapV2Router: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "SimpleUniswapV2Router: ZERO_ADDRESS");
    }
    
    /**
     * @dev Gets the pair address for two tokens
     */
    function _getPair(address tokenA, address tokenB) internal view returns (address) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        return SimpleUniswapV2Factory(factory).getPair(token0, token1);
    }
    
    /**
     * @dev Gets the reserves of a pair
     */
    function getReserves(address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        address pair = SimpleUniswapV2Factory(factory).getPair(token0, token1);
        require(pair != address(0), "SimpleUniswapV2Router: PAIR_DOES_NOT_EXIST");
        
        (uint reserve0, uint reserve1) = SimpleUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    
    /**
     * @dev Calculates the optimal amount of tokenB to match with a given amount of tokenA
     */
    function quote(uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB) {
        require(amountA > 0, "SimpleUniswapV2Router: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "SimpleUniswapV2Router: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }
    
    /**
     * @dev Calculates the output amount for a swap
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, "SimpleUniswapV2Router: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "SimpleUniswapV2Router: INSUFFICIENT_LIQUIDITY");
        
        uint amountInWithFee = amountIn * 997; // 0.3% fee
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    /**
     * @dev Calculates the input amount for a given output amount
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure returns (uint amountIn) {
        require(amountOut > 0, "SimpleUniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "SimpleUniswapV2Router: INSUFFICIENT_LIQUIDITY");
        
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
    
    /**
     * @dev Gets or creates a pair
     */
    function _getPairOrCreate(address tokenA, address tokenB) internal returns (address) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        address pair = SimpleUniswapV2Factory(factory).getPair(token0, token1);
        
        if (pair == address(0)) {
            pair = SimpleUniswapV2Factory(factory).createPair(token0, token1);
        }
        
        return pair;
    }
    
    /**
     * @dev Calculates optimal liquidity amounts
     */
    function _calculateLiquidityAmounts(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal view returns (uint amountA, uint amountB) {
        (uint reserveA, uint reserveB) = getReserves(tokenA, tokenB);
        
        if (reserveA == 0 && reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
            return (amountA, amountB);
        }
        
        uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
        
        if (amountBOptimal <= amountBDesired) {
            require(amountBOptimal >= amountBMin, "SimpleUniswapV2Router: INSUFFICIENT_B_AMOUNT");
            amountA = amountADesired;
            amountB = amountBOptimal;
        } else {
            uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
            require(amountAOptimal <= amountADesired, "SimpleUniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
            require(amountAOptimal >= amountAMin, "SimpleUniswapV2Router: INSUFFICIENT_A_AMOUNT");
            amountA = amountAOptimal;
            amountB = amountBDesired;
        }
    }
    
    /**
     * @dev Adds liquidity to a pair
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        address pair = _getPairOrCreate(tokenA, tokenB);
        
        (amountA, amountB) = _calculateLiquidityAmounts(
            tokenA, 
            tokenB, 
            amountADesired, 
            amountBDesired, 
            amountAMin, 
            amountBMin
        );
        
        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);
        
        liquidity = SimpleUniswapV2Pair(pair).mint(to);
        
        require(liquidity > 0, "SimpleUniswapV2Router: INSUFFICIENT_LIQUIDITY_MINTED");
    }
    
    /**
     * @dev Removes liquidity from a pair
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = _getPair(tokenA, tokenB);
        require(pair != address(0), "SimpleUniswapV2Router: PAIR_DOES_NOT_EXIST");
        
        SimpleUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity);
        
        (uint amount0, uint amount1) = SimpleUniswapV2Pair(pair).burn(to);
        
        (address token0,) = sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        
        require(amountA >= amountAMin, "SimpleUniswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "SimpleUniswapV2Router: INSUFFICIENT_B_AMOUNT");
    }
    
    /**
     * @dev Calculates output amounts for a path of tokens
     */
    function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, "SimpleUniswapV2Router: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        
        for (uint i = 0; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
    
    /**
     * @dev Calculates input amounts for a path of tokens
     */
    function getAmountsIn(uint amountOut, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, "SimpleUniswapV2Router: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
    
    /**
     * @dev Swaps an exact amount of input tokens for as many output tokens as possible
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SimpleUniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        
        address pair = _getPair(path[0], path[1]);
        require(pair != address(0), "SimpleUniswapV2Router: PAIR_DOES_NOT_EXIST");
        
        _safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        
        _swap(amounts, path, to);
        
        return amounts;
    }
    
    /**
     * @dev Swaps tokens for an exact amount of output tokens
     */
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, "SimpleUniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        
        address pair = _getPair(path[0], path[1]);
        require(pair != address(0), "SimpleUniswapV2Router: PAIR_DOES_NOT_EXIST");
        
        _safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        
        _swap(amounts, path, to);
        
        return amounts;
    }
    
    /**
     * @dev Executes a swap
     * 假设SimpleUniswapV2Pair.swap方法有3个参数
     */
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        for (uint i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            
            (uint amount0Out, uint amount1Out) = input == token0 
                ? (uint(0), amountOut) 
                : (amountOut, uint(0));
                
            address to = i < path.length - 2 
                ? _getPair(output, path[i + 2]) 
                : _to;
                
            // 使用3个参数的swap方法
            SimpleUniswapV2Pair(_getPair(input, output)).swap(amount0Out, amount1Out, to);
        }
    }
    
    /**
     * @dev Safely transfers tokens from one address to another
     */
    function _safeTransferFrom(address token, address from, address to, uint value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SimpleUniswapV2Router: TRANSFER_FAILED"
        );
    }
}