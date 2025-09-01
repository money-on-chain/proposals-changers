// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/**
 * @title IMoCv2
 * @notice Minimal interface for MoC v2 contract (only methods used by changers)
 */
interface IMoCv2 {
  /// @notice Returns the TC interest rate (1e18 precision).
  function tcInterestRate() external view returns (uint256);
  /// @notice Returns the TC mint fee (1e18 precision).
  function tcMintFee() external view returns (uint256);
  /// @notice Returns the TC redeem fee (1e18 precision).
  function tcRedeemFee() external view returns (uint256);
  /// @notice Returns the swap TP for TP fee (1e18 precision).
  function swapTPforTPFee() external view returns (uint256);
  /// @notice Returns the swap TP for TC fee (1e18 precision).
  function swapTPforTCFee() external view returns (uint256);
  /// @notice Returns the swap TC for TP fee (1e18 precision).
  function swapTCforTPFee() external view returns (uint256);
  /// @notice Returns the redeem TC and TP fee (1e18 precision).
  function redeemTCandTPFee() external view returns (uint256);
  /// @notice Returns the mint TC and TP fee (1e18 precision).
  function mintTCandTPFee() external view returns (uint256);
  /// @notice Returns the fee token percentage (1e18 precision).
  function feeTokenPct() external view returns (uint256);

  /**
   * @dev sets the interest rate for Collateral Tokens (TC).
   * @param tcInterestRate_ new interest rate for Collateral Tokens [PREC]
   * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setTCInterestRate(uint256 tcInterestRate_) external;

  /**
   * @dev sets the fee charged on Token Collateral mint.
   * @param tcMintFee_ addition fee pct applied on Collateral Tokens mint [PREC]
   * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setTcMintFee(uint256 tcMintFee_) external;

  /**
   * @dev sets the fee charged on Token Collateral redeem.
   * @param tcRedeemFee_ addition fee pct applied on Collateral Tokens redeem [PREC]
   * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setTcRedeemFee(uint256 tcRedeemFee_) external;

  /**
   * @dev sets the fee charged when swap a Pegged Token for another Pegged Token.
   * @param swapTPforTPFee_ additional fee pct applied on swap a Pegged Token for another Pegged Token [PREC]
   * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setSwapTPforTPFee(uint256 swapTPforTPFee_) external;

  /**
   * @dev sets the fee charged when swap a Pegged Token for Collateral Token.
   * @param swapTPforTCFee_ additional fee pct applied on swap a Pegged Token for Collateral Token [PREC]
   * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setSwapTPforTCFee(uint256 swapTPforTCFee_) external;

  /**
   * @dev sets the fee charged when swap Collateral Token for a Pegged Token.
   * @param swapTCforTPFee_ additional fee pct applied on swap Collateral Token for a Pegged Token [PREC]
   * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setSwapTCforTPFee(uint256 swapTCforTPFee_) external;

  /**
   * @dev sets the fee charged when redeem Collateral Token and Pegged Token in one operation.
   * @param redeemTCandTPFee_ additional fee pct applied on redeem Collateral Token and Pegged Token [PREC]
   * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setRedeemTCandTPFee(uint256 redeemTCandTPFee_) external;

  /**
   * @dev sets the fee charged when mint Collateral Token and Pegged Token in one operation.
   * @param mintTCandTPFee_ additional fee pct applied on mint Collateral Token and Pegged Token [PREC]
   * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setMintTCandTPFee(uint256 mintTCandTPFee_) external;

  /**
   * @dev sets the fee applied on the top of the operation`s fee when using Fee Token as fee payment method.
   * @param feeTokenPct_ pct applied on the top of the operation`s fee when using Fee Token
   *  as fee payment method [PREC]
   *  e.g. if tcMintFee = 1%, FeeTokenPct = 50% => qFeeToken = 0.5%
   *  0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
   */
  function setFeeTokenPct(uint256 feeTokenPct_) external;
}
