// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { IDataProvider } from "@moc/main/contracts/interfaces/IDataProvider.sol";

interface IMocSwapperV3MultiHop {
  /**
   * @notice sets a new path to the swapper
   * @param tokenA_ address of the first token
   * @param tokenB_ address of the second token
   * @param intermediateTokens_ array of intermediate tokens
   * @param fees_ array of fees for each hop
   * @param providerSwappingAtoB_ address of the max amount to swap provider for tokenA -> tokenB
   */
  function setPath(
    address tokenA_,
    address tokenB_,
    address[] memory intermediateTokens_,
    uint24[] memory fees_,
    IDataProvider providerSwappingAtoB_
  ) external;

  /**
   * @notice Returns the max amount to swap provider for a given tokenIn -> tokenOut pair
   */
  function maxAmountToSwapProviders(address tokenIn_, address tokenOut_) external view returns (IDataProvider);
}

/**
 * @title SetMocSwapperPath
 * @notice ChangeContract used to set the swap paths on a MocSwapperV3MultiHop contract
 *         for the RIF <-> MoC directions.
 *         The existing maxAmountToSwapProviders are read from the swapper on-chain and reused.
 */
contract SetMocSwapperPath is IChangeContract {
  IMocSwapperV3MultiHop public immutable mocSwapper;

  address public immutable rifToken;
  address public immutable mocToken;

  address[] public rifToMocIntermediateTokens;
  uint24[] public rifToMocFees;

  address[] public mocToRifIntermediateTokens;
  uint24[] public mocToRifFees;

  /**
   * @notice Constructor
   * @param mocSwapper_ Address of the MocSwapperV3MultiHop contract
   * @param rifToken_ Address of the RIF token
   * @param mocToken_ Address of the MoC token
   * @param rifToMocIntermediateTokens_ Intermediate tokens for the RIF -> MoC path
   * @param rifToMocFees_ Fees for each hop in the RIF -> MoC path (length = intermediates + 1)
   * @param mocToRifIntermediateTokens_ Intermediate tokens for the MoC -> RIF path
   * @param mocToRifFees_ Fees for each hop in the MoC -> RIF path (length = intermediates + 1)
   */
  constructor(
    address mocSwapper_,
    address rifToken_,
    address mocToken_,
    address[] memory rifToMocIntermediateTokens_,
    uint24[] memory rifToMocFees_,
    address[] memory mocToRifIntermediateTokens_,
    uint24[] memory mocToRifFees_
  ) {
    mocSwapper = IMocSwapperV3MultiHop(mocSwapper_);
    rifToken = rifToken_;
    mocToken = mocToken_;
    rifToMocIntermediateTokens = rifToMocIntermediateTokens_;
    rifToMocFees = rifToMocFees_;
    mocToRifIntermediateTokens = mocToRifIntermediateTokens_;
    mocToRifFees = mocToRifFees_;
  }

  /**
   * @inheritdoc IChangeContract
   * @notice Sets the RIF -> MoC and MoC -> RIF paths on the MocSwapper.
   *         The existing maxAmountToSwapProviders are read from the swapper and reused.
   */
  function execute() external {
    // Read existing providers from the swapper on-chain
    IDataProvider rifToMocProvider = mocSwapper.maxAmountToSwapProviders(rifToken, mocToken);
    IDataProvider mocToRifProvider = mocSwapper.maxAmountToSwapProviders(mocToken, rifToken);

    // Set the new RIF -> MoC path
    mocSwapper.setPath(rifToken, mocToken, rifToMocIntermediateTokens, rifToMocFees, rifToMocProvider);

    // Set the new MoC -> RIF path
    mocSwapper.setPath(mocToken, rifToken, mocToRifIntermediateTokens, mocToRifFees, mocToRifProvider);
  }
}
