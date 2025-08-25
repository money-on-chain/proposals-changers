// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { IMoCInrate } from "../../interfaces/IMoCInrate.sol";

/// @title FeesAndBitprorateProposal
/// @author Money On Chain
/// @notice Changer that: (1) sets BitPro rate, (2) sets commission fees by tx type
/// @dev Designed for a single execution via governance. Uses a "fuse" pattern to prevent re-execution.
contract FeesAndBitprorateProposal is IChangeContract {
    /// @notice Error for zero address
    error ZeroAddress();
    /// @notice Error for empty commission rates
    error EmptyCommissionRates();
    /// @notice Error for too many commission rates
    error TooManyCommissionRates();
    /// @notice Error for already executed changer
    error AlreadyExecuted();

    /// @notice MoCInrate contract (minimal interface)
    IMoCInrate public mocInrate;

    /// @notice New BitPro rate (check expected decimals in MoCInrate)
    uint256 public bitProRate;

    /// @notice Struct for commission rates
    struct CommissionRates {
        uint8 txType; ///< Transaction type
        uint256 fee; ///< Fee for the transaction type
    }

    /// @notice Array of commission rates
    CommissionRates[] public commissionRates;

    /// @notice Hard cap to keep gas bounded when initializing fees
    uint8 public constant COMMISSION_RATES_ARRAY_MAX_LENGTH = 50;

    /// @notice Emitted after setting BitPro rate
    /// @param newRate The new BitPro rate set
    event BitProRateSet(uint256 indexed newRate);

    /// @notice Emitted per txType after setting its commission fee
    /// @param txType The transaction type
    /// @param fee The fee set for the transaction type
    event CommissionRateSet(uint8 indexed txType, uint256 indexed fee);

    /// @notice Emitted once after the changer finishes and burns its own references
    event ExecutedOnce();

    /// @notice Constructor for FeesAndBitprorateProposal
    /// @param _mocInrate MoCInrate contract (minimal interface)
    /// @param _bitProRate New BitPro rate (check expected decimals in MoCInrate)
    /// @param _commissionRates Array of (txType, fee) pairs to initialize in MoCInrate
    constructor(IMoCInrate _mocInrate, uint256 _bitProRate, CommissionRates[] memory _commissionRates) {
        if (address(_mocInrate) == address(0)) revert ZeroAddress();
        if (_commissionRates.length == 0) revert EmptyCommissionRates();
        if (!(_commissionRates.length < COMMISSION_RATES_ARRAY_MAX_LENGTH + 1)) revert TooManyCommissionRates();

        mocInrate = _mocInrate;
        bitProRate = _bitProRate;

        // Copy fee schedule to storage (bounded by COMMISSION_RATES_ARRAY_MAX_LENGTH)
        for (uint256 i = 0; i < _commissionRates.length; ++i) {
            commissionRates.push(_commissionRates[i]);
        }
    }

    /// @notice Executes the changer exactly once. Callable by governance.
    /// @dev Uses a double guard (both mocInrate and moc must be non-zero). After running,
    ///      both are zeroed out to burn references and prevent re-execution.
    function execute() external override {
        if (address(mocInrate) == address(0)) revert AlreadyExecuted();

        // (1) Set the new BitPro rate
        mocInrate.setBitProRate(bitProRate);
        emit BitProRateSet(bitProRate);

        // (2) Initialize commission fees by tx type
        if (commissionRates.length == 0) revert EmptyCommissionRates();
        if (!(commissionRates.length < COMMISSION_RATES_ARRAY_MAX_LENGTH + 1)) revert TooManyCommissionRates();
        for (uint256 i = 0; i < commissionRates.length; ++i) {
            mocInrate.setCommissionRateByTxType(commissionRates[i].txType, commissionRates[i].fee);
            emit CommissionRateSet(commissionRates[i].txType, commissionRates[i].fee);
        }

        // Burn references to prevent any future execution attempts
        mocInrate = IMoCInrate(address(0));

        emit ExecutedOnce();
    }

    /// @notice Returns number of (txType, fee) pairs configured
    /// @return The number of commission rates
    function commissionRatesLength() external view returns (uint256) {
        return commissionRates.length;
    }
}
