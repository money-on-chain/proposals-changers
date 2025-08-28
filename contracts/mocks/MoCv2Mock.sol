// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MoCv2Mock
/// @notice Minimal mock for ROC v2 used in tests. It exposes:
///         - tcInterestRate (BitPro/RIFPro rate)
///         - All fee fields with 1e18 precision
/// @dev    No access control; setters are open by design for unit tests.
contract MoCv2Mock {

    // --- Rate (1e18 precision) ------------------------------------------------
    uint256 public tcInterestRate;

    // --- Fees (1e18 precision) ------------------------------------------------
    uint256 public tcMintFee;
    uint256 public tcRedeemFee;
    uint256 public swapTPforTPFee;
    uint256 public swapTPforTCFee;
    uint256 public swapTCforTPFee;
    uint256 public redeemTCandTPFee;
    uint256 public mintTCandTPFee;
    uint256 public feeTokenPct;

    // --- Events (optional, handy for debugging) --------------------------------
    event TCInterestRateSet(uint256 newRate);

    event TcMintFeeSet(uint256 value);
    event TcRedeemFeeSet(uint256 value);
    event SwapTPforTPFeeSet(uint256 value);
    event SwapTPforTCFeeSet(uint256 value);
    event SwapTCforTPFeeSet(uint256 value);
    event RedeemTCandTPFeeSet(uint256 value);
    event MintTCandTPFeeSet(uint256 value);
    event FeeTokenPctSet(uint256 value);

    // --- Setters ---------------------------------------------------------------

    /**
     * @dev sets TC interest rate
     * @param tcInterestRate_ pct interest charged to TC holders on the total collateral in the protocol [PREC]
     */
    function setTCInterestRate(uint256 tcInterestRate_) external {
        tcInterestRate = tcInterestRate_;
        emit TCInterestRateSet(tcInterestRate_);
    }


    /**
     * @dev sets the fee charged on Token Collateral mint.
     * @param tcMintFee_ addition fee pct applied on Collateral Tokens mint [PREC]
     * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
     */
    function setTcMintFee(uint256 tcMintFee_) external {
        tcMintFee = tcMintFee_;
        emit TcMintFeeSet(tcMintFee_);
    }

    /**
     * @dev sets the fee charged on Token Collateral redeem.
     * @param tcRedeemFee_ addition fee pct applied on Collateral Tokens redeem [PREC]
     * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
     */
    function setTcRedeemFee(uint256 tcRedeemFee_) external {
        tcRedeemFee = tcRedeemFee_;
        emit TcRedeemFeeSet(tcRedeemFee_);
    }

    /**
     * @dev sets the fee charged when swap a Pegged Token for another Pegged Token.
     * @param swapTPforTPFee_ additional fee pct applied on swap a Pegged Token for another Pegged Token [PREC]
     * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
     */
    function setSwapTPforTPFee(uint256 swapTPforTPFee_) external {
        swapTPforTPFee = swapTPforTPFee_;
        emit SwapTPforTPFeeSet(swapTPforTPFee_);
    }

    /**
     * @dev sets the fee charged when swap a Pegged Token for Collateral Token.
     * @param swapTPforTCFee_ additional fee pct applied on swap a Pegged Token for Collateral Token [PREC]
     * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
     */
    function setSwapTPforTCFee(uint256 swapTPforTCFee_) external {
        swapTPforTCFee = swapTPforTCFee_;
        emit SwapTPforTCFeeSet(swapTPforTCFee_);
    }

    /**
     * @dev sets the fee charged when swap Collateral Token for a Pegged Token.
     * @param swapTCforTPFee_ additional fee pct applied on swap Collateral Token for a Pegged Token [PREC]
     * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
     */
    function setSwapTCforTPFee(uint256 swapTCforTPFee_) external {
        swapTCforTPFee = swapTCforTPFee_;
        emit SwapTCforTPFeeSet(swapTCforTPFee_);
    }

    /**
     * @dev sets the fee charged when redeem Collateral Token and Pegged Token in one operation.
     * @param redeemTCandTPFee_ additional fee pct applied on redeem Collateral Token and Pegged Token [PREC]
     * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
     */
    function setRedeemTCandTPFee(uint256 redeemTCandTPFee_) external {
        redeemTCandTPFee = redeemTCandTPFee_;
        emit RedeemTCandTPFeeSet(redeemTCandTPFee_);
    }

    /**
     * @dev sets the fee charged when mint Collateral Token and Pegged Token in one operation.
     * @param mintTCandTPFee_ additional fee pct applied on mint Collateral Token and Pegged Token [PREC]
     * 0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
     */
    function setMintTCandTPFee(uint256 mintTCandTPFee_) external {
        mintTCandTPFee = mintTCandTPFee_;
        emit MintTCandTPFeeSet(mintTCandTPFee_);
    }

    /**
     * @dev sets the fee applied on the top of the operation`s fee when using Fee Token as fee payment method.
     * @param feeTokenPct_ pct applied on the top of the operation`s fee when using Fee Token
     *  as fee payment method [PREC]
     *  e.g. if tcMintFee = 1%, FeeTokenPct = 50% => qFeeToken = 0.5%
     *  0% = 0; 1% = 10 ** 16; 100% = 10 ** 18
     */
    function setFeeTokenPct(uint256 feeTokenPct_) external {
        feeTokenPct = feeTokenPct_;
        emit FeeTokenPctSet(feeTokenPct_);
    }
}
