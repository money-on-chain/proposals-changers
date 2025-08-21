// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { IMoCInrate } from "../../interfaces/IMoCInrate.sol";


/**
 * @title FeesAndBitprorateProposal
 * @notice Changer that: (1) sets BitPro rate, (2) sets commission fees by tx type
 * @dev Designed for a single execution via governance. Uses a "fuse" pattern to prevent re-execution.
 */
contract FeesAndBitprorateProposal is IChangeContract {
    IMoCInrate public mocInrate;
    
    uint256 public bitProRate;

    struct CommissionRates {
        uint8 txType;
        uint256 fee;
    }

    CommissionRates[] public commissionRates;

    /// @notice Hard cap to keep gas bounded when initializing fees
    uint8 public constant COMMISSION_RATES_ARRAY_MAX_LENGTH = 50;

    /// @notice Emitted after setting BitPro rate
    event BitProRateSet(uint256 newRate);

    /// @notice Emitted per txType after setting its commission fee
    event CommissionRateSet(uint8 indexed txType, uint256 fee);
    
    /// @notice Emitted once after the changer finishes and burns its own references
    event ExecutedOnce();

    /**
     * @param _mocInrate MoCInrate contract (minimal interface)     
     * @param _bitProRate New BitPro rate (check expected decimals in MoCInrate)
     * @param _commissionRates Array of (txType, fee) pairs to initialize in MoCInrate
     */
    constructor(
        IMoCInrate _mocInrate,        
        uint256 _bitProRate,
        CommissionRates[] memory _commissionRates
    ) {
        // Sanity checks on external targets and inputs
        require(address(_mocInrate) != address(0), "Wrong MoCInrate address");        
        require(_commissionRates.length > 0, "commissionRates cannot be empty");
        require(
            _commissionRates.length <= COMMISSION_RATES_ARRAY_MAX_LENGTH,
            "commissionRates length must be between 1 and 50"
        );

        mocInrate = _mocInrate;        
        bitProRate = _bitProRate;

        // Copy fee schedule to storage (bounded by COMMISSION_RATES_ARRAY_MAX_LENGTH)
        for (uint256 i = 0; i < _commissionRates.length; ) {
            commissionRates.push(_commissionRates[i]);
            unchecked { ++i; }
        }
    }

    /**
     * @notice Executes the changer exactly once. Callable by governance.
     * @dev Uses a double guard (both mocInrate and moc must be non-zero). After running,
     *      both are zeroed out to burn references and prevent re-execution.
     */
    function execute() external {
        // One-time execution fuse: both references must be intact
        require(address(mocInrate) != address(0), "This changer was already executed");        

        // (1) Set the new BitPro rate
        mocInrate.setBitProRate(bitProRate);
        emit BitProRateSet(bitProRate);

        // (2) Initialize commission fees by tx type
        require(commissionRates.length > 0, "commissionRates cannot be empty");
        require(
            commissionRates.length <= COMMISSION_RATES_ARRAY_MAX_LENGTH,
            "commissionRates length must be between 1 and 50"
        );
        for (uint256 i = 0; i < commissionRates.length; ) {
            mocInrate.setCommissionRateByTxType(commissionRates[i].txType, commissionRates[i].fee);
            emit CommissionRateSet(commissionRates[i].txType, commissionRates[i].fee);
            unchecked { ++i; }
        }
        
        // Burn references to prevent any future execution attempts
        mocInrate = IMoCInrate(address(0));
        
        emit ExecutedOnce();
    }

    /// @notice Returns number of (txType, fee) pairs configured
    function commissionRatesLength() external view returns (uint256) {
        return commissionRates.length;
    }
}
