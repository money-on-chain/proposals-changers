// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { FeesAndBitprorateProposal } from "../changers/fees_and_bitprorate/FeesAndBitprorateProposal.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IMoCInrate } from "../interfaces/IMoCInrate.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

/// @title FeesAndBitprorateProposalTest
/// @author Money On Chain
/// @notice Test suite for FeesAndBitprorateProposal contract
/// @title FeesAndBitprorateProposalTest
/// @author Money On Chain
/// @notice Test suite for FeesAndBitprorateProposal contract
contract FeesAndBitprorateProposalTest is Test {
    /// @notice The proposal contract under test
    FeesAndBitprorateProposal public proposal;
    /// @notice The MoCInrate contract used for testing
    IMoCInrate public mocInrate;

    /// @notice Sets up the test environment and initializes the proposal contract
    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://public-node.rsk.co");
        vm.selectFork(mainnetFork);
        mocInrate = IMoCInrate(0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3);
        // Hardcoded values from deployConfig-rskMainnet.json
        uint256 bitProRate = 98_000_000_000_000; // 0.000098 with 18 decimals (example, adjust as needed)
        FeesAndBitprorateProposal.CommissionRates[] memory rates = new FeesAndBitprorateProposal.CommissionRates[](12);

        uint256 feeRBTC = 1_500_000_000_000_000;
        uint256 feeMOC = 1_200_000_000_000_000;

        // Define commission rates for each transaction type
        uint256[12] memory fees = [
            feeRBTC, // feeRBTC for txType 0-5
            feeRBTC,
            feeRBTC,
            feeRBTC,
            feeRBTC,
            feeRBTC,
            feeMOC, // feeMOC for txType 6-11
            feeMOC,
            feeMOC,
            feeMOC,
            feeMOC,
            feeMOC
        ];

        for (uint8 i = 0; i < 12; ++i) {
            rates[i] = FeesAndBitprorateProposal.CommissionRates({ txType: i, fee: fees[i] });
        }
        proposal = new FeesAndBitprorateProposal(IMoCInrate(address(mocInrate)), bitProRate, rates);
    }

    /// @notice Ensures the constructor reverts if the MoCInrate address is zero.
    /// @notice Ensures the constructor reverts if the MoCInrate address is zero.
    function test_ConstructorRevertsOnZeroMoCInrate() public {
        FeesAndBitprorateProposal.CommissionRates[] memory rates = new FeesAndBitprorateProposal.CommissionRates[](1);
        rates[0] = FeesAndBitprorateProposal.CommissionRates({ txType: 1, fee: 100 });
        vm.expectRevert(FeesAndBitprorateProposal.ZeroAddress.selector);
        new FeesAndBitprorateProposal(IMoCInrate(address(0)), 1, rates);
    }

    /// @notice Ensures the constructor reverts if the commissionRates array is empty.
    /// @notice Ensures the constructor reverts if the commissionRates array is empty.
    function test_ConstructorRevertsOnEmptyRates() public {
        FeesAndBitprorateProposal.CommissionRates[] memory rates = new FeesAndBitprorateProposal.CommissionRates[](0);
        vm.expectRevert(FeesAndBitprorateProposal.EmptyCommissionRates.selector);
        new FeesAndBitprorateProposal(IMoCInrate(address(mocInrate)), 1, rates);
    }

    /// @notice Ensures the constructor reverts if the commissionRates array exceeds the maximum allowed length.
    /// @notice Ensures the constructor reverts if the commissionRates array exceeds the maximum allowed length.
    function test_ConstructorRevertsOnTooManyRates() public {
        FeesAndBitprorateProposal.CommissionRates[] memory rates = new FeesAndBitprorateProposal.CommissionRates[](51);
        for (uint256 i = 0; i < 51; ++i) {
            rates[i] = FeesAndBitprorateProposal.CommissionRates({ txType: uint8(i), fee: i });
        }
        vm.expectRevert(FeesAndBitprorateProposal.TooManyCommissionRates.selector);
        new FeesAndBitprorateProposal(IMoCInrate(address(mocInrate)), 1, rates);
    }

    /// @notice Verifies that the constructor initializes all state variables correctly with valid parameters.
    /// Checks mocInrate address, bitProRate value, and commissionRates length.
    /// @notice Verifies that the constructor initializes all state variables correctly with valid parameters.
    /// @dev Checks mocInrate address, bitProRate value, and commissionRates length.
    function test_ConstructorInitializesState() public view {
        assert(address(proposal.mocInrate()) == address(mocInrate));
        assert(proposal.bitProRate() == 98_000_000_000_000);
        assert(proposal.commissionRatesLength() == 12);
    }

    /// @notice Verifies that execute() reverts when called by an unauthorized address.
    /// @notice Verifies that execute() reverts when called by an unauthorized address.
    function test_ExecuteRevertsNotAuthorized() public {
        // reverts trying to execute directly
        vm.expectRevert("not_authorized_changer");
        proposal.execute();

        // reverts trying to execute through the governor without voting
        IGovernor governor = IGovernor(mocInrate.governor());
        vm.expectRevert();
        governor.executeChange(proposal);
    }

    /// @notice Executes the proposal and verifies that the BitPro rate and commission rates are set correctly.
    /// @notice Executes the proposal and verifies that the BitPro rate and commission rates are set correctly.
    function test_Execute() public {
        (IGovernor governor, address governorOwner) = _getGovernor();
        vm.prank(governorOwner);
        governor.executeChange(proposal);

        assert(mocInrate.bitProRate() == 98_000_000_000_000);

        uint256 feeRBTC = 1_500_000_000_000_000;
        uint256 feeMOC = 1_200_000_000_000_000;
        // Check all commission rates
        uint256[12] memory expectedFees = [
            feeRBTC, // feeRBTC for txType 0-5
            feeRBTC,
            feeRBTC,
            feeRBTC,
            feeRBTC,
            feeRBTC,
            feeMOC, // feeMOC for txType 6-11
            feeMOC,
            feeMOC,
            feeMOC,
            feeMOC,
            feeMOC
        ];

        for (uint8 i = 0; i < 12; ++i) {
            assert(mocInrate.commissionRatesByTxType(i) == expectedFees[i]);
        }
    }

    /// @notice Ensures that execute() can only be called once and reverts on subsequent calls.
    /// @notice Ensures that execute() can only be called once and reverts on subsequent calls.
    function test_ExecuteCanOnlyRunOnce() public {
        (IGovernor governor, address governorOwner) = _getGovernor();
        vm.prank(governorOwner);
        governor.executeChange(proposal);

        vm.expectRevert(FeesAndBitprorateProposal.AlreadyExecuted.selector);
        vm.prank(governorOwner);
        governor.executeChange(proposal);
    }

    /// @notice Gets the governor and its owner address
    /// @return governor The IGovernor instance
    /// @return governorOwner The address of the governor's owner
    function _getGovernor() internal view returns (IGovernor governor, address governorOwner) {
        governor = IGovernor(mocInrate.governor());
        governorOwner = Ownable(address(governor)).owner();
        return (governor, governorOwner);
    }
}
