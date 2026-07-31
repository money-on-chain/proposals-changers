// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import { UniswapV3Oracle } from "@moc/price-oracle-interfaces/contracts/UniswapV3Oracle.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract DeployableUniswapV3Oracle is UniswapV3Oracle {
  constructor(address pool, uint32 twapInterval, address quoteToken)
    UniswapV3Oracle(IUniswapV3Pool(pool), twapInterval, quoteToken)
  {}
}
