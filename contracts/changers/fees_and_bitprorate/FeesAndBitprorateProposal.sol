// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { IMoCInrate } from "../../interfaces/IMoCInrate.sol";
import { IMoCv2 } from "../../interfaces/IMoCv2.sol";

/**
 * @title FeesAndBitprorateProposal
 * @notice Governance changer that: (1) sets BitPro/RIFPro rate on MoC V1 & ROC V2,
 *         (2) sets commission fees by tx type on MoC V1,
 *         (3) sets operation fees on ROC V2.
 * @dev Delegatecall-safe: `execute()` does not write this contract’s storage. All parameters
 *      are set in the constructor and decoded in memory during execution.
 *      One-shot semantics must be enforced by the Governor (this changer does not burn a fuse).
 */
contract FeesAndBitprorateProposal is IChangeContract {
  /// @dev Fixed-point precision expected by targets (0% = 0, 1% = 1e16, 100% = 1e18).
  uint256 private constant PREC = 1e18;

  /// @notice Upper bound to keep gas predictable when applying V1 commissions.
  uint8 public constant COMMISSION_RATES_ARRAY_MAX_LENGTH = 50;

  /// @notice Minimal (txType, fee) pair for MoC V1 commissions.
  struct CommissionRates {
    uint8 txType;
    uint256 fee; // 1e18 precision
  }

  /**
   * @notice Identifiers for adjustable ROC V2 fees.
   * @dev All values use [PREC=1e18]. 0% = 0; 1% = 1e16; 100% = 1e18.
   */
  enum RocV2FeeKey {
    TcMintFee,
    TcRedeemFee,
    SwapTPforTPFee,
    SwapTPforTCFee,
    SwapTCforTPFee,
    RedeemTCandTPFee,
    MintTCandTPFee,
    FeeTokenPct
  }

  /**
   * @notice Readable pair used off-chain and by view helpers for ROC V2 fees.
   */
  struct RocV2FeeUpdate {
    RocV2FeeKey key;
    uint256 value; // 1e18 precision
  }

  // -----------------------------------------------------------------------
  // Constructor-set parameters (stored once; `execute()` does not mutate storage)
  // -----------------------------------------------------------------------

  /// @notice MoC Inrate (V1) contract.
  IMoCInrate public immutable mocInrate;

  /// @notice ROC V2 (RIF on Chain v2) contract.
  IMoCv2 public immutable rocV2;

  /// @notice New BitPro/RIFPro interest rate (1e18 precision).
  uint256 public immutable bitProRate;

  /// @notice Packed MoC V1 commissions: abi.encode(uint8[] txTypes, uint256[] fees).
  bytes private commissionRatesBlob;

  /// @notice Packed ROC V2 fees: abi.encode(uint8[] keys, uint256[] values).
  bytes private rocV2FeeBlob;

  // -----------------------------------------------------------------------
  // Events
  // -----------------------------------------------------------------------

  /// @notice Emitted after setting BitPro/RIFPro rate on both targets.
  event BitProRateSet(uint256 newRate);

  /// @notice Emitted per txType after setting its commission fee in MoC Inrate.
  event CommissionRateSet(uint8 indexed txType, uint256 fee);

  /// @notice Emitted per key after applying its fee in ROC V2.
  event RocV2FeeApplied(RocV2FeeKey indexed key, uint256 value);

  /// @notice Emitted once after executing all operations.
  event ExecutedOnce();

  // -----------------------------------------------------------------------
  // Constructor
  // -----------------------------------------------------------------------

  /**
   * @param _mocInrate        MoC Inrate target (V1).
   * @param _rocV2            ROC V2 target.
   * @param _bitProRate       New BitPro/RIFPro rate (1e18).
   * @param _commissionRates  Array of (txType, fee) to apply on MoC Inrate.
   * @param _rocV2Fees        Array of (key, value) to apply on ROC V2.
   */
  constructor(
    IMoCInrate _mocInrate,
    IMoCv2 _rocV2,
    uint256 _bitProRate,
    CommissionRates[] memory _commissionRates,
    RocV2FeeUpdate[] memory _rocV2Fees
  ) {
    require(address(_mocInrate) != address(0), "Wrong MoCInrate address");
    require(address(_rocV2) != address(0), "Wrong ROCv2 address");
    require(_commissionRates.length > 0, "commissionRates empty");
    require(
      _commissionRates.length <= COMMISSION_RATES_ARRAY_MAX_LENGTH,
      "commissionRates too long"
    );
    require(_rocV2Fees.length > 0, "rocV2Fees empty");
    require(_rocV2Fees.length <= COMMISSION_RATES_ARRAY_MAX_LENGTH, "rocV2Fees too long");
    require(_bitProRate <= PREC, "rate > 100%");

    // Pack MoC V1 commissions.
    uint256 len = _commissionRates.length;
    uint8[] memory t = new uint8[](len);
    uint256[] memory f = new uint256[](len);
    for (uint256 i = 0; i < len; ) {
      t[i] = _commissionRates[i].txType;
      uint256 fee = _commissionRates[i].fee;
      require(fee <= PREC, "MoC V1 fee > 100%");
      f[i] = fee;
      unchecked {
        ++i;
      }
    }

    // Pack ROC V2 fees.
    uint8[] memory k = new uint8[](_rocV2Fees.length);
    uint256[] memory v = new uint256[](_rocV2Fees.length);
    for (uint256 i = 0; i < _rocV2Fees.length; ) {
      k[i] = uint8(_rocV2Fees[i].key);
      uint256 val = _rocV2Fees[i].value;
      require(val <= PREC, "ROC V2 fee > 100%");
      v[i] = val;
      unchecked {
        ++i;
      }
    }

    mocInrate = _mocInrate;
    rocV2 = _rocV2;
    bitProRate = _bitProRate;
    commissionRatesBlob = abi.encode(t, f); // written once in constructor
    rocV2FeeBlob = abi.encode(k, v); // written once in constructor
  }

  // -----------------------------------------------------------------------
  // Read helpers (human-friendly, for pre-vote inspection)
  // -----------------------------------------------------------------------

  /// @notice Returns the decoded list of MoC V1 commissions.
  function getCommissionRates() external view returns (CommissionRates[] memory out) {
    (uint8[] memory t, uint256[] memory f) = abi.decode(commissionRatesBlob, (uint8[], uint256[]));
    require(t.length == f.length, "MoC V1 blob mismatch");
    out = new CommissionRates[](t.length);
    for (uint256 i = 0; i < t.length; ) {
      out[i] = CommissionRates({ txType: t[i], fee: f[i] });
      unchecked {
        ++i;
      }
    }
  }

  /// @notice Returns the decoded list of ROC V2 fee updates.
  function getRocV2Fees() external view returns (RocV2FeeUpdate[] memory out) {
    (uint8[] memory k, uint256[] memory v) = abi.decode(rocV2FeeBlob, (uint8[], uint256[]));
    require(k.length == v.length, "ROC V2 blob mismatch");
    out = new RocV2FeeUpdate[](k.length);
    for (uint256 i = 0; i < k.length; ) {
      out[i] = RocV2FeeUpdate(RocV2FeeKey(k[i]), v[i]);
      unchecked {
        ++i;
      }
    }
  }

  /// @notice (Optional) Expose raw blobs if you prefer off-chain decoding with AbiCoder.
  function commissionRatesBlobRaw() external view returns (bytes memory) {
    return commissionRatesBlob;
  }
  function rocV2FeeBlobRaw() external view returns (bytes memory) {
    return rocV2FeeBlob;
  }

  // -----------------------------------------------------------------------
  // Execute (no storage writes; safe under delegatecall)
  // -----------------------------------------------------------------------

  /**
   * @notice Applies the new BitPro/RIFPro rate and all configured fees on MoC V1 & ROC V2.
   * @dev This function does not modify this contract’s storage. The Governor
   *      should enforce single execution if required by your governance model.
   */
  function execute() external {
    // (1) Apply BitPro/RIFPro rate on both systems.
    mocInrate.setBitProRate(bitProRate);
    rocV2.setTCInterestRate(bitProRate);
    emit BitProRateSet(bitProRate);

    // (2) Apply commission fees by txType on MoC V1.
    (uint8[] memory t, uint256[] memory f) = abi.decode(commissionRatesBlob, (uint8[], uint256[]));
    require(t.length == f.length && t.length > 0, "commissionRates bad blob");
    for (uint256 i = 0; i < t.length; ) {
      mocInrate.setCommissionRateByTxType(t[i], f[i]);
      emit CommissionRateSet(t[i], f[i]);
      unchecked {
        ++i;
      }
    }

    // (3) Apply operation fees on ROC V2.
    (uint8[] memory k, uint256[] memory v) = abi.decode(rocV2FeeBlob, (uint8[], uint256[]));
    require(k.length == v.length && k.length > 0, "rocV2Fee bad blob");

    for (uint256 i = 0; i < k.length; ) {
      RocV2FeeKey key = RocV2FeeKey(k[i]);
      uint256 val = v[i];
      require(val <= PREC, "rocV2Fee > 100%");

      if (key == RocV2FeeKey.TcMintFee) {
        rocV2.setTcMintFee(val);
      } else if (key == RocV2FeeKey.TcRedeemFee) {
        rocV2.setTcRedeemFee(val);
      } else if (key == RocV2FeeKey.SwapTPforTPFee) {
        rocV2.setSwapTPforTPFee(val);
      } else if (key == RocV2FeeKey.SwapTPforTCFee) {
        rocV2.setSwapTPforTCFee(val);
      } else if (key == RocV2FeeKey.SwapTCforTPFee) {
        rocV2.setSwapTCforTPFee(val);
      } else if (key == RocV2FeeKey.RedeemTCandTPFee) {
        rocV2.setRedeemTCandTPFee(val);
      } else if (key == RocV2FeeKey.MintTCandTPFee) {
        rocV2.setMintTCandTPFee(val);
      } else if (key == RocV2FeeKey.FeeTokenPct) {
        rocV2.setFeeTokenPct(val);
      } else {
        revert("unknown key");
      }

      emit RocV2FeeApplied(key, val);
      unchecked {
        ++i;
      }
    }

    emit ExecutedOnce();
  }
}
