// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import { PriceProviderInverse } from "@moc/price-oracle-interfaces/contracts/PriceProviderInverse.sol";
import { IPriceProvider } from "@moc/price-oracle-interfaces/contracts/interfaces/IPriceProvider.sol";

contract DeployablePriceProviderInverse is PriceProviderInverse {
  constructor(address priceProvider) PriceProviderInverse(IPriceProvider(priceProvider)) {}
}
