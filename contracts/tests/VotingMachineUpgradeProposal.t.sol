// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {
  VotingMachineUpgradeProposal,
  IUpgradeDelegator
} from "../changers/upgrade_votingMachine/VotingMachineUpgradeProposal.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";
import "forge-std/console.sol";

interface Vm {
  struct Log {
    bytes32[] topics;
    bytes data;
    address emitter;
  }

  function createSelectFork(
    string calldata urlOrAlias,
    uint256 blockNumber
  ) external returns (uint256);
  function load(address target, bytes32 slot) external view returns (bytes32 data);
  function getCode(string calldata artifactPath) external returns (bytes memory bytecode);
  function readFile(string calldata path) external view returns (string memory);
  function parseJsonAddress(
    string calldata json,
    string calldata key
  ) external pure returns (address);
  function prank(address msgSender) external;
  function store(address target, bytes32 slot, bytes32 value) external;
  function expectRevert() external;
  function expectRevert(bytes calldata revertData) external;
  function recordLogs() external;
  function getRecordedLogs() external returns (Log[] memory);
}

interface IGoverned {
  function governor() external view returns (address);
}

interface IOwnableLike {
  function owner() external view returns (address);
}

struct Vote {
        address addr;
        uint96 round;
    }
  
interface IVotingMachineProbe {
  function getVotingRound() external view returns (uint256);
  function getState() external view returns (uint256);
  function preVote(address changeContractAddress) external;
  function votes(address voter) external view returns (Vote memory);
}

contract VotingMachineUpgradeProposalForkTest {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  string internal constant MAINNET_PARAMS_PATH =
    "ignition/modules/upgrade_votingMachine/parameters/rskMainnet.json";

  uint256 internal constant FORK_BLOCK = 8864900;

  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant PRE_VOTE_EVENT_SIG =
    keccak256("PreVoteEvent(address,address,uint256,uint256)");

  // VotingMachineStorage slot for `votingRound`:
  // Initializable (slot 0 + gap[50]) + Governed (governor + gap[50]) + controlledGovernor + registry
  // => votingRound lives at slot 104.
  uint256 internal constant VOTING_ROUND_SLOT = 104;

  address internal votingMachineProxy;
  address internal upgradeDelegator;
  address internal newVotingMachineImplementation;

  function setUp() public {
    vm.createSelectFork("https://public-node.rsk.co", FORK_BLOCK);
    _readMainnetParamsFromJson();
    newVotingMachineImplementation = _deployFromArtifact(
      "contracts/compat/DeployableVotingMachine.sol:DeployableVotingMachine"
    );
    _forceVotingRoundTo260(votingMachineProxy);
  }

  function testFork_ExecuteChangerAsGovernorOwner() public {
    _executeChanger();

    address implementationAfter = _loadAddress(votingMachineProxy, IMPLEMENTATION_SLOT);
    require(
      implementationAfter == newVotingMachineImplementation,
      "voting machine implementation was not upgraded"
    );
  }

  function testFork_AlreadyVotedBug_BeforeChanger() public {
    uint256 votingRound = IVotingMachineProbe(votingMachineProxy).getVotingRound();
    require(votingRound >= 255, "test requires votingRound >= 255");

    uint256 votingState = IVotingMachineProbe(votingMachineProxy).getState();
    require(votingState == 0, "test requires pre-voting state");

    address voter = address(0xBFD33A62E03fb7C649E771E37F2d2d5Bb008cca4);
    address proposal1 = address(0xCAFE0001);
    address proposal2 = address(0xCAFE0002);

    vm.prank(voter);
    IVotingMachineProbe(votingMachineProxy).preVote(proposal1);
    require(IVotingMachineProbe(votingMachineProxy).votes(voter).round == 4, "vote was not registered for round 4");
    
    vm.prank(voter);
    IVotingMachineProbe(votingMachineProxy).preVote(proposal2);
    require(IVotingMachineProbe(votingMachineProxy).votes(voter).round == 4, "vote was not registered for round 4");
  }

  function testFork_AlreadyVotedBug_IsFixedAfterChanger() public {
    _executeChanger();
    
    uint256 votingRound = IVotingMachineProbe(votingMachineProxy).getVotingRound();
    require(votingRound >= 255, "test requires votingRound >= 255");

    uint256 votingState = IVotingMachineProbe(votingMachineProxy).getState();
    require(votingState == 0, "test requires pre-voting state");

    address voter = address(0xBFD33A62E03fb7C649E771E37F2d2d5Bb008cca4);
    address proposal1 = address(0xCAFE0001);
    address proposal2 = address(0xCAFE0002);

    vm.prank(voter);
    IVotingMachineProbe(votingMachineProxy).preVote(proposal1);
    require(IVotingMachineProbe(votingMachineProxy).votes(voter).round == 260, "vote was not registered for round 260");
    
    vm.prank(voter);
    vm.expectRevert("Must vote the same proposal");
    IVotingMachineProbe(votingMachineProxy).preVote(proposal2);
    require(IVotingMachineProbe(votingMachineProxy).votes(voter).round == 260, "vote was not registered for round 260");
  }

  function _deployFromArtifact(string memory artifactPath) internal returns (address deployed) {
    bytes memory bytecode = vm.getCode(artifactPath);
    require(bytecode.length != 0, "artifact bytecode is empty");
    assembly ("memory-safe") {
      deployed := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    require(deployed != address(0), "deployment failed");
  }

  function _forceVotingRoundTo260(address votingMachineProxy_) internal {
    vm.store(votingMachineProxy_, bytes32(VOTING_ROUND_SLOT), bytes32(uint256(260)));
    require(
      IVotingMachineProbe(votingMachineProxy_).getVotingRound() == 260,
      "failed to set votingRound to 260"
    );
  }

  function _executeChanger() internal {
    require(
      _loadAddress(votingMachineProxy, IMPLEMENTATION_SLOT) != newVotingMachineImplementation,
      "new implementation must differ from current"
    );

    VotingMachineUpgradeProposal changer = new VotingMachineUpgradeProposal(
      votingMachineProxy,
      IUpgradeDelegator(upgradeDelegator),
      newVotingMachineImplementation
    );

    IGovernor governor = IGovernor(IGoverned(upgradeDelegator).governor());
    address governorOwner = IOwnableLike(address(governor)).owner();

    vm.prank(governorOwner);
    governor.executeChange(IChangeContract(address(changer)));
  }

  function _readMainnetParamsFromJson() internal {
    string memory json = vm.readFile(MAINNET_PARAMS_PATH);

    votingMachineProxy = vm.parseJsonAddress(
      json,
      ".VotingMachineUpgradeChangerModule.votingMachineProxy"
    );
    upgradeDelegator = vm.parseJsonAddress(
      json,
      ".VotingMachineUpgradeChangerModule.upgradeDelegator"
    );

    require(votingMachineProxy != address(0), "votingMachineProxy is zero");
    require(upgradeDelegator != address(0), "upgradeDelegator is zero");
  }

  function _loadAddress(address target, bytes32 slot) internal view returns (address loadedAddress) {
    return address(uint160(uint256(vm.load(target, slot))));
  }
}
