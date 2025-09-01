// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FeesAndBitprorateProposal} from "../changers/fees_and_bitprorate/FeesAndBitprorateProposal.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMoCInrate} from "../interfaces/IMoCInrate.sol";
import {IMoCv2} from "../interfaces/IMoCv2.sol";
import {IGovernor} from "../interfaces/IGovernor.sol";

/// @title FeesAndBitprorateProposalTest
/// @notice Test suite for FeesAndBitprorateProposal contract.
contract FeesAndBitprorateProposalTest is Test {
    FeesAndBitprorateProposal proposal;
    IMoCInrate mocInrate;
    IMoCv2 rocV2;

    /// @notice Sets up the test environment with mainnet fork and proposal deployment.
    function setUp() public {
        // Fork mainnet and use real addresses from deployConfig
        uint256 mainnetFork = vm.createFork("https://public-node.rsk.co");
        vm.selectFork(mainnetFork);

        // Addresses from deployConfig
        address mocInrateAddr = 0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3;
        address rocV2Addr = 0xA27024Ed70035E46dba712609fc2Afa1c97aA36A;
        mocInrate = IMoCInrate(mocInrateAddr);
        rocV2 = IMoCv2(rocV2Addr);

        // bitProRate: "0.000143211085680495" to 18 decimals
        uint256 bitProRate = 143211085680495;

        // Commission rates (txType, fee) from deployConfig
        uint8[12] memory txTypes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
        uint256[12] memory fees = [
            uint256(1_500_000_000_000_000), // 0.0015 * 1e18
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_000_000_000_000_000, // 0.0010 * 1e18
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000
        ];
        FeesAndBitprorateProposal.CommissionRates[]
            memory rates = new FeesAndBitprorateProposal.CommissionRates[](12);
        for (uint8 i = 0; i < 12; i++) {
            rates[i] = FeesAndBitprorateProposal.CommissionRates({
                txType: txTypes[i],
                fee: fees[i]
            });
        }

        // ROC V2 fees from deployConfig
        FeesAndBitprorateProposal.RocV2FeeUpdate[]
            memory rocFees = new FeesAndBitprorateProposal.RocV2FeeUpdate[](8);
        rocFees[0] = FeesAndBitprorateProposal.RocV2FeeUpdate({
            key: FeesAndBitprorateProposal.RocV2FeeKey.TcMintFee,
            value: 1_500_000_000_000_000
        });
        rocFees[1] = FeesAndBitprorateProposal.RocV2FeeUpdate({
            key: FeesAndBitprorateProposal.RocV2FeeKey.TcRedeemFee,
            value: 1_500_000_000_000_000
        });
        rocFees[2] = FeesAndBitprorateProposal.RocV2FeeUpdate({
            key: FeesAndBitprorateProposal.RocV2FeeKey.SwapTPforTPFee,
            value: 1_500_000_000_000_000
        });
        rocFees[3] = FeesAndBitprorateProposal.RocV2FeeUpdate({
            key: FeesAndBitprorateProposal.RocV2FeeKey.SwapTPforTCFee,
            value: 1_500_000_000_000_000
        });
        rocFees[4] = FeesAndBitprorateProposal.RocV2FeeUpdate({
            key: FeesAndBitprorateProposal.RocV2FeeKey.SwapTCforTPFee,
            value: 1_500_000_000_000_000
        });
        rocFees[5] = FeesAndBitprorateProposal.RocV2FeeUpdate({
            key: FeesAndBitprorateProposal.RocV2FeeKey.RedeemTCandTPFee,
            value: 1_500_000_000_000_000
        });
        rocFees[6] = FeesAndBitprorateProposal.RocV2FeeUpdate({
            key: FeesAndBitprorateProposal.RocV2FeeKey.MintTCandTPFee,
            value: 1_500_000_000_000_000
        });
        rocFees[7] = FeesAndBitprorateProposal.RocV2FeeUpdate({
            key: FeesAndBitprorateProposal.RocV2FeeKey.FeeTokenPct,
            value: 666_666_666_666_666_666
        });

        proposal = new FeesAndBitprorateProposal(
            mocInrate,
            rocV2,
            bitProRate,
            rates,
            rocFees
        );
    }

    /// @notice Verifies that the constructor initializes all state variables correctly with valid parameters.
    function test_ConstructorInitializesState() public view {
        assert(address(proposal.mocInrate()) == address(mocInrate));
        assert(address(proposal.rocV2()) == address(rocV2));
        assert(proposal.bitProRate() == 143211085680495);
        // Check commission rates and ROC V2 fees via read helpers
        FeesAndBitprorateProposal.CommissionRates[] memory rates = proposal
            .getCommissionRates();
        assert(rates.length == 12);
        uint256[12] memory expectedFees = [
            uint256(1_500_000_000_000_000),
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000
        ];
        for (uint8 i = 0; i < 12; i++) {
            assert(rates[i].txType == i);
            assert(rates[i].fee == expectedFees[i]);
        }
        FeesAndBitprorateProposal.RocV2FeeUpdate[] memory fees = proposal
            .getRocV2Fees();
        assert(fees.length == 8);
        uint256[8] memory expectedRocFees = [
            uint256(1_500_000_000_000_000),
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            666_666_666_666_666_666
        ];
        for (uint8 i = 0; i < 8; i++) {
            assert(fees[i].value == expectedRocFees[i]);
        }
    }

    /// @notice Ensures that only the governor owner can execute the proposal.
    function test_ExecuteRevertsIfNotAuthorized() public {
        (IGovernor governor, ) = _getGovernor();
        // Try to execute as a random address (not the governor owner)
        address notOwner = address(0x1234);
        vm.prank(notOwner);
        vm.expectRevert();
        governor.executeChange(proposal);

        // Try to execute the proposal as not the governor
        vm.expectRevert("not_authorized_changer");
        proposal.execute();
    }

    /// @notice Executes the proposal as the governor owner and checks all effects on MoCInrate and RocV2.
    function test_Execute() public {
        (IGovernor governor, address governorOwner) = _getGovernor();
        vm.prank(governorOwner);
        governor.executeChange(proposal);

        // Check BitPro rate set on mocInrate and rocV2
        assertEq(mocInrate.bitProRate(), 143211085680495);
        assertEq(rocV2.tcInterestRate(), 143211085680495);

        // Check commission rates set on mocInrate
        uint256[12] memory expectedFees = [
            uint256(1_500_000_000_000_000),
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_500_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000,
            1_000_000_000_000_000
        ];
        for (uint8 i = 0; i < 12; i++) {
            assertEq(mocInrate.commissionRatesByTxType(i), expectedFees[i]);
        }

        // Check ROC V2 fees set on rocV2
        assertEq(rocV2.tcMintFee(), 1_500_000_000_000_000);
        assertEq(rocV2.tcRedeemFee(), 1_500_000_000_000_000);
        assertEq(rocV2.swapTPforTPFee(), 1_500_000_000_000_000);
        assertEq(rocV2.swapTPforTCFee(), 1_500_000_000_000_000);
        assertEq(rocV2.swapTCforTPFee(), 1_500_000_000_000_000);
        assertEq(rocV2.redeemTCandTPFee(), 1_500_000_000_000_000);
        assertEq(rocV2.mintTCandTPFee(), 1_500_000_000_000_000);
        assertEq(rocV2.feeTokenPct(), 666_666_666_666_666_666);
    }

    /// @notice Helper to get the governor contract and its owner.
    /// @return governor The IGovernor instance
    /// @return governorOwner The address of the governor's owner
    function _getGovernor()
        internal
        view
        returns (IGovernor governor, address governorOwner)
    {
        governor = IGovernor(mocInrate.governor());
        governorOwner = Ownable(address(governor)).owner();
        return (governor, governorOwner);
    }
}
