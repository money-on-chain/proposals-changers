// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IUpgradeDelegator, MIP263701UseTimestamps } from "../changers/mip26_3701/MIP263701UseTimestamps.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

interface IGovernedSchedule {
  function governor() external view returns (address);
}

interface IOwnableGovernor {
  function owner() external view returns (address);
}

interface IMoCStateTimestampScheduleProbe {
  function lastEmaCalculationTimestamp() external view returns (uint256);
  function emaCalculationTimeSpan() external view returns (uint256);
}

interface IMoCInrateTimestampScheduleProbe {
  function lastBitProInterestTimestamp() external view returns (uint256);
  function bitProInterestTimeSpan() external view returns (uint256);
}

interface ICoinerTimestampScheduleProbe {
  function getNextMintAt() external view returns (uint256);
  function getMintTimestampInterval() external view returns (uint256);
}

/**
 * @notice Applies MIP26-3701 to the deployed Rootstock mainnet state at the
 *         proposal anchor and reports the timestamps produced by the migration.
 */
contract MIP263701UseTimestampsForkTest is Test {
  string internal constant MAINNET_PARAMS_PATH =
    "./ignition/modules/MIP26-3701/parameters/rskMainnet.json";

  uint256 internal constant SEPTEMBER_2026_START = 1_788_220_800;
  uint256 internal constant OCTOBER_2026_START = 1_790_812_800;

  address internal mocProxy;
  address internal mocStateProxy;
  address internal mocInrateProxy;
  address internal coinerProxy;
  address internal mocUpgradeDelegator;
  address internal flowUpgradeDelegator;
  uint256 internal anchorBlockNumber;
  uint256 internal anchorTimestamp;

  MIP263701UseTimestamps internal changer;

  function setUp() public {
    _readMainnetParameters();

    string memory defaultRpcUrl = "https://public-node.rsk.co";
    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", defaultRpcUrl);
    vm.createSelectFork(rpcUrl, anchorBlockNumber);

    changer = new MIP263701UseTimestamps(
      mocProxy,
      mocStateProxy,
      mocInrateProxy,
      coinerProxy,
      IUpgradeDelegator(mocUpgradeDelegator),
      IUpgradeDelegator(flowUpgradeDelegator),
      _deployArtifact("DeployableMoC"),
      _deployArtifact("DeployableMoCState"),
      _deployArtifact("DeployableMoCInrate"),
      _deployArtifact("DeployableCoiner"),
      anchorBlockNumber,
      anchorTimestamp
    );
  }

  function testFork_ExecutionMigratesCurrentMainnetSchedules() public {
    uint256 expectedLastEmaCalculationTimestamp = changer.legacyLastEmaCalculationTimestamp();
    uint256 expectedLastInterestPaymentTimestamp = changer.legacyLastInterestPaymentTimestamp();
    uint256 expectedNextMintTimestamp = changer.nextMintDueTimestamp();

    _executeChanger();

    uint256 lastEmaCalculationTimestamp = IMoCStateTimestampScheduleProbe(mocStateProxy)
      .lastEmaCalculationTimestamp();
    uint256 lastInterestPaymentTimestamp = IMoCInrateTimestampScheduleProbe(mocInrateProxy)
      .lastBitProInterestTimestamp();
    uint256 nextMintTimestamp = ICoinerTimestampScheduleProbe(coinerProxy).getNextMintAt();

    emit log_named_uint("EMA previous calculation timestamp", lastEmaCalculationTimestamp);
    emit log_named_uint("Weekly interest previous payment timestamp", lastInterestPaymentTimestamp);
    emit log_named_uint("Coiner next round timestamp", nextMintTimestamp);

    assertEq(lastEmaCalculationTimestamp, expectedLastEmaCalculationTimestamp);
    assertEq(lastInterestPaymentTimestamp, expectedLastInterestPaymentTimestamp);
    assertEq(nextMintTimestamp, expectedNextMintTimestamp);
    assertEq(IMoCStateTimestampScheduleProbe(mocStateProxy).emaCalculationTimeSpan(), 1 days);
    assertEq(IMoCInrateTimestampScheduleProbe(mocInrateProxy).bitProInterestTimeSpan(), 7 days);
    assertEq(
      ICoinerTimestampScheduleProbe(coinerProxy).getMintTimestampInterval(),
      30 days + 10 hours
    );

    assertGe(nextMintTimestamp, SEPTEMBER_2026_START, "Coiner round is before September");
    assertLt(nextMintTimestamp, OCTOBER_2026_START, "Coiner round drifted into October");
  }

  function _executeChanger() internal {
    address governor = IGovernedSchedule(mocStateProxy).governor();
    vm.prank(IOwnableGovernor(governor).owner());
    IGovernor(governor).executeChange(IChangeContract(address(changer)));
  }

  function _deployArtifact(string memory artifactName) internal returns (address deployed) {
    bytes memory creationCode = vm.getCode(artifactName);
    assembly {
      deployed := create(0, add(creationCode, 0x20), mload(creationCode))
    }
    require(deployed != address(0), "implementation deployment failed");
  }

  function _readMainnetParameters() internal {
    string memory json = vm.readFile(MAINNET_PARAMS_PATH);
    string memory module = "MIP263701Module";

    mocProxy = vm.parseJsonAddress(json, _key(module, "mocProxy"));
    mocStateProxy = vm.parseJsonAddress(json, _key(module, "mocStateProxy"));
    mocInrateProxy = vm.parseJsonAddress(json, _key(module, "mocInrateProxy"));
    coinerProxy = vm.parseJsonAddress(json, _key(module, "coinerProxy"));
    mocUpgradeDelegator = vm.parseJsonAddress(json, _key(module, "mocUpgradeDelegator"));
    flowUpgradeDelegator = vm.parseJsonAddress(json, _key(module, "flowUpgradeDelegator"));
    anchorBlockNumber = vm.parseJsonUint(json, _key(module, "anchorBlockNumber"));
    anchorTimestamp = vm.parseJsonUint(json, _key(module, "anchorTimestamp"));
  }

  function _key(string memory module, string memory field) internal pure returns (string memory) {
    return string(abi.encodePacked(".", module, ".", field));
  }
}
