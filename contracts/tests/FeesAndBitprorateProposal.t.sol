// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import { Test } from "forge-std/Test.sol";
import { FeesAndBitprorateProposal } from "../changers/fees_and_bitprorate/FeesAndBitprorateProposal.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IMoCInrate } from "../interfaces/IMoCInrate.sol";
import { IMoCv2 }  from "../interfaces/IMoCv2.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

contract FeesAndBitprorateProposalTest is Test {
    FeesAndBitprorateProposal proposal;
    IMoCInrate mocInrate;

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://public-node.rsk.co");
        vm.selectFork(mainnetFork);
        mocInrate = IMoCInrate(0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3);
        rocV2 = IMoCv2(0xA27024Ed70035E46dba712609fc2Afa1c97aA36A);
        // Hardcoded values from deployConfig-rskMainnet.json
        uint256 bitProRate = 143_211_085_680_495; // 0.000143211085680495 with 18 decimals (example, adjust as needed)
        FeesAndBitprorateProposal.CommissionRates[] memory rates = new FeesAndBitprorateProposal.CommissionRates[](12);

        uint256 FEE_RBTC = 1_500_000_000_000_000;
        uint256 FEE_MOC = 1_000_000_000_000_000;

        // Define commission rates for each transaction type
        uint256[12] memory fees = [
            FEE_RBTC, // FEE_RBTC for txType 0-5
            FEE_RBTC,
            FEE_RBTC,
            FEE_RBTC,
            FEE_RBTC,
            FEE_RBTC,
            FEE_MOC, // FEE_MOC for txType 6-11
            FEE_MOC,
            FEE_MOC,
            FEE_MOC,
            FEE_MOC,
            FEE_MOC
        ];

        for (uint8 i = 0; i < 12; i++) {
            rates[i] = FeesAndBitprorateProposal.CommissionRates({ txType: i, fee: fees[i] });
        }
        proposal = new FeesAndBitprorateProposal(IMoCInrate(address(mocInrate)), bitProRate, rates);
    }

    /// @notice Ensures the constructor reverts if the MoCInrate address is zero.
    function test_ConstructorRevertsOnZeroMoCInrate() public {
        FeesAndBitprorateProposal.CommissionRates[] memory rates = new FeesAndBitprorateProposal.CommissionRates[](1);
        rates[0] = FeesAndBitprorateProposal.CommissionRates({ txType: 1, fee: 100 });
        vm.expectRevert("Wrong MoCInrate address");
        new FeesAndBitprorateProposal(IMoCInrate(address(0)), 1, rates);
    }

    /// @notice Ensures the constructor reverts if the commissionRates array is empty.
    function test_ConstructorRevertsOnEmptyRates() public {
        FeesAndBitprorateProposal.CommissionRates[] memory rates = new FeesAndBitprorateProposal.CommissionRates[](0);
        vm.expectRevert("commissionRates cannot be empty");
        new FeesAndBitprorateProposal(IMoCInrate(address(mocInrate)), 1, rates);
    }

    /// @notice Ensures the constructor reverts if the commissionRates array exceeds the maximum allowed length.
    function test_ConstructorRevertsOnTooManyRates() public {
        FeesAndBitprorateProposal.CommissionRates[] memory rates = new FeesAndBitprorateProposal.CommissionRates[](51);
        for (uint256 i = 0; i < 51; i++) {
            rates[i] = FeesAndBitprorateProposal.CommissionRates({ txType: uint8(i), fee: i });
        }
        vm.expectRevert("commissionRates length must be between 1 and 50");
        new FeesAndBitprorateProposal(IMoCInrate(address(mocInrate)), 1, rates);
    }

    /// @notice Verifies that the constructor initializes all state variables correctly with valid parameters.
    /// Checks mocInrate address, bitProRate value, and commissionRates length.
    function test_ConstructorInitializesState() public view {
        assert(address(proposal.mocInrate()) == address(mocInrate));
        assert(proposal.bitProRate() == 98_000_000_000_000);
        assert(proposal.commissionRatesLength() == 12);
    }

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
    function test_Execute() public {
        (IGovernor governor, address governorOwner) = _getGovernor();
        vm.prank(governorOwner);
        governor.executeChange(proposal);

        assert(mocInrate.bitProRate() == 98_000_000_000_000);

        uint256 FEE_RBTC = 1_500_000_000_000_000;
        uint256 FEE_MOC = 1_200_000_000_000_000;
        // Check all commission rates
        uint256[12] memory expectedFees = [
            FEE_RBTC, // FEE_RBTC for txType 0-5
            FEE_RBTC,
            FEE_RBTC,
            FEE_RBTC,
            FEE_RBTC,
            FEE_RBTC,
            FEE_MOC, // FEE_MOC for txType 6-11
            FEE_MOC,
            FEE_MOC,
            FEE_MOC,
            FEE_MOC,
            FEE_MOC
        ];
        
        for (uint8 i = 0; i < 12; i++) {
            assert(mocInrate.commissionRatesByTxType(i) == expectedFees[i]);
        }
    }

    /// @notice Ensures that execute() can only be called once and reverts on subsequent calls.
    function test_ExecuteCanOnlyRunOnce() public {
        (IGovernor governor, address governorOwner) = _getGovernor();
        vm.prank(governorOwner);
        governor.executeChange(proposal);

        vm.expectRevert("This changer was already executed");
        vm.prank(governorOwner);
        governor.executeChange(proposal);
    }

    function _getGovernor() internal view returns (IGovernor governor, address governorOwner) {
        governor = IGovernor(mocInrate.governor());
        governorOwner = Ownable(address(governor)).owner();
        return (governor, governorOwner);
    }
}