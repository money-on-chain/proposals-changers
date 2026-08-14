// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { VotingMachineUpgradeProposal, IRegistry, IUpgradeDelegator } from "../changers/voting_machine_upgrade/VotingMachineUpgradeProposal.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

interface IGoverned {
  function governor() external view returns (address);
}

interface IOwnableLike {
  function owner() external view returns (address);
}

interface IVotingMachineRegistry {
  function registry() external view returns (IRegistry);
}

interface IRegistryProbe {
  function getUint(bytes32 key) external view returns (uint248);
  function getAddress(bytes32 key) external view returns (address);
}

interface IERC20Probe {
  function totalSupply() external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
}

interface IStakingProbe {
  function deposit(uint256 amount) external;
}

interface IMoCMaxGasPrice {
  function maxGasPrice() external view returns (uint256);
  function setMaxGasPrice(uint256 maxGasPrice) external;
}

contract SetMocMaxGasPriceChanger is IChangeContract {
  IMoCMaxGasPrice public immutable moc;
  uint256 public immutable newMaxGasPrice;

  constructor(IMoCMaxGasPrice moc_, uint256 newMaxGasPrice_) {
    moc = moc_;
    newMaxGasPrice = newMaxGasPrice_;
  }

  function execute() external override {
    moc.setMaxGasPrice(newMaxGasPrice);
  }
}

interface IVotingMachineProbe {
  function getVotingRound() external view returns (uint256);
  function getState() external view returns (uint256);
  function preVote(address changeContractAddress) external;
  function acceptedStep() external;
  function preVoteStep() external;
  function vote(bool inFavorAgainst) external;
  function voteStep() external;
  function votes(address voter) external view returns (address addr, uint96 round);
  function proposalProposer(address proposal) external view returns (address);
  function proposalAcceptedTimestamp(address proposal) external view returns (uint256);
}

contract VotingMachineUpgradeProposalForkTest is Test {
  string internal constant MAINNET_PARAMS_PATH =
    "ignition/modules/upgrade_votingMachine/parameters/rskMainnet.json";
  uint256 internal constant FORK_BLOCK = 8980146;
  uint256 internal constant EXPECTED_PRIORITY_TIME_DELTA = 86400;
  address internal constant MOC_V1_PROXY = 0xf773B590aF754D597770937Fa8ea7AbDf2668370;

  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant PRIORITY_TIME_DELTA_KEY =
    0x966841a4b245a1fdec6244a638f8c320312779e88c67bc05fde78d6c98c5a9aa;
  bytes32 internal constant MOC_TOKEN_KEY =
    0x4bd5e7ff929fdd1ba62a33f76e0f40e97bb35e8bf126c0d9d91ce5c69a4bc521;
  bytes32 internal constant MOC_STAKING_MACHINE_KEY =
    0x3c557531fea67120f21bc7711270a96f1b8cff3dfe3dd798a8a9f09ce9b77972;
  bytes32 internal constant PRE_VOTE_EXPIRATION_TIME_DELTA_KEY =
    0x62f5dbf0c17b0df83487409f747ad2eeca5fd54c140ca59b32cf39d6f6eaf916;
  bytes32 internal constant VOTING_TIME_DELTA_KEY =
    0xb43ee0a5ee6dcc7115ce824e4e353526ad6e479afa4daeb78451070de942de36;
  uint256 internal constant VOTING_ROUND_SLOT = 104;
  uint256 internal constant VOTING_STATE_SLOT = 106;

  address internal votingMachineProxy;
  address internal upgradeDelegator;
  uint256 internal acceptedStepPriorityTimeDelta;
  address internal newVotingMachineImplementation;
  IRegistry internal registry;

  function setUp() public {
    vm.createSelectFork("https://public-node.rsk.co", FORK_BLOCK);
    _readMainnetParamsFromJson();
    newVotingMachineImplementation = _deployFromArtifact(
      "contracts/compat/DeployableVotingMachine.sol:DeployableVotingMachine"
    );
    registry = IVotingMachineRegistry(votingMachineProxy).registry();
    _forceVotingRoundTo260();
  }

  function testFork_DeployAndExecuteChanger() public {
    _executeChanger();

    assertEq(
      _loadAddress(votingMachineProxy, IMPLEMENTATION_SLOT),
      newVotingMachineImplementation,
      "VotingMachine implementation was not upgraded"
    );
    assertEq(
      IRegistryProbe(address(registry)).getUint(PRIORITY_TIME_DELTA_KEY),
      EXPECTED_PRIORITY_TIME_DELTA,
      "accepted step priority time delta was not configured"
    );
  }

  function testFork_AlreadyVotedBug_BeforeChanger() public {
    assertGe(IVotingMachineProbe(votingMachineProxy).getVotingRound(), 255);
    assertEq(IVotingMachineProbe(votingMachineProxy).getState(), 0);

    address voter = address(0xBFD33A62E03fb7C649E771E37F2d2d5Bb008cca4);
    address proposal1 = address(0xCAFE0001);
    address proposal2 = address(0xCAFE0002);

    vm.prank(voter);
    IVotingMachineProbe(votingMachineProxy).preVote(proposal1);
    (, uint96 firstVoteRound) = IVotingMachineProbe(votingMachineProxy).votes(voter);
    assertEq(firstVoteRound, 4, "vote was not registered for the buggy round");

    vm.prank(voter);
    IVotingMachineProbe(votingMachineProxy).preVote(proposal2);
    (, uint96 secondVoteRound) = IVotingMachineProbe(votingMachineProxy).votes(voter);
    assertEq(secondVoteRound, 4, "legacy implementation behavior changed unexpectedly");
  }

  function testFork_AlreadyVotedBug_IsFixedAfterChanger() public {
    _executeChanger();

    assertGe(IVotingMachineProbe(votingMachineProxy).getVotingRound(), 255);
    assertEq(IVotingMachineProbe(votingMachineProxy).getState(), 0);

    address voter = address(0xBFD33A62E03fb7C649E771E37F2d2d5Bb008cca4);
    address proposal1 = address(0xCAFE0001);
    address proposal2 = address(0xCAFE0002);

    vm.prank(voter);
    IVotingMachineProbe(votingMachineProxy).preVote(proposal1);
    (, uint96 firstVoteRound) = IVotingMachineProbe(votingMachineProxy).votes(voter);
    assertEq(firstVoteRound, 260, "vote was not registered in the current round");

    vm.prank(voter);
    vm.expectRevert("Must vote the same proposal");
    IVotingMachineProbe(votingMachineProxy).preVote(proposal2);
    (, uint96 secondVoteRound) = IVotingMachineProbe(votingMachineProxy).votes(voter);
    assertEq(secondVoteRound, 260, "vote round changed after rejected proposal");
  }

  function testFork_RecordsTheAddressThatFirstSubmittedTheProposal() public {
    _executeChanger();
    address proposal = address(0xCAFE0003);
    _acceptProposal(proposal);

    assertEq(
      IVotingMachineProbe(votingMachineProxy).proposalProposer(proposal),
      address(0x1001),
      "proposal proposer was not recorded"
    );
  }

  function testFork_RestrictsAcceptedStepToProposerDuringPriorityWindow() public {
    _executeChanger();

    address proposal = address(0xCAFE0004);
    _acceptProposal(proposal);

    vm.prank(address(0x1002));
    vm.expectRevert("Only proposer can execute during priority window");
    IVotingMachineProbe(votingMachineProxy).acceptedStep();

    vm.prank(address(0x1001));
    IVotingMachineProbe(votingMachineProxy).acceptedStep();

    assertEq(IVotingMachineProbe(votingMachineProxy).getState(), 0);
    assertEq(IVotingMachineProbe(votingMachineProxy).proposalProposer(proposal), address(0));
    assertEq(IVotingMachineProbe(votingMachineProxy).proposalAcceptedTimestamp(proposal), 0);
  }

  function testFork_AllowsAnyAddressToExecuteAfterPriorityWindow() public {
    _executeChanger();

    address proposal = address(0xCAFE0005);
    _acceptProposal(proposal);

    vm.warp(block.timestamp + acceptedStepPriorityTimeDelta + 1);
    vm.prank(address(0x1002));
    IVotingMachineProbe(votingMachineProxy).acceptedStep();

    assertEq(IVotingMachineProbe(votingMachineProxy).getState(), 0);
  }

  function testFork_ExecutesARealChangerAfterVotingMachineUpgrade() public {
    _executeChanger();

    IMoCMaxGasPrice moc = IMoCMaxGasPrice(MOC_V1_PROXY);
    uint256 newMaxGasPrice = moc.maxGasPrice() + 1;
    SetMocMaxGasPriceChanger realChanger = new SetMocMaxGasPriceChanger(moc, newMaxGasPrice);

    _acceptProposal(address(realChanger));

    vm.prank(address(0x1001));
    IVotingMachineProbe(votingMachineProxy).acceptedStep();

    assertEq(moc.maxGasPrice(), newMaxGasPrice, "real changer was not executed");
    assertEq(IVotingMachineProbe(votingMachineProxy).getState(), 0);
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
    acceptedStepPriorityTimeDelta = vm.parseJsonUint(
      json,
      ".VotingMachineUpgradeChangerModule.acceptedStepPriorityTimeDelta"
    );

    require(votingMachineProxy != address(0), "votingMachineProxy is zero");
    require(upgradeDelegator != address(0), "upgradeDelegator is zero");
    require(
      acceptedStepPriorityTimeDelta == EXPECTED_PRIORITY_TIME_DELTA,
      "unexpected accepted step priority time delta"
    );
  }

  function _loadAddress(address target, bytes32 slot) internal view returns (address) {
    return address(uint160(uint256(vm.load(target, slot))));
  }

  function _forceVotingRoundTo260() internal {
    vm.store(votingMachineProxy, bytes32(VOTING_ROUND_SLOT), bytes32(uint256(260)));
    vm.store(votingMachineProxy, bytes32(VOTING_STATE_SLOT), bytes32(0));
    assertEq(
      IVotingMachineProbe(votingMachineProxy).getVotingRound(),
      260,
      "failed to set voting round to 260"
    );
    assertEq(
      IVotingMachineProbe(votingMachineProxy).getState(),
      0,
      "failed to set pre-voting state"
    );
  }

  function _acceptProposal(address proposal) internal {
    address token = IRegistryProbe(address(registry)).getAddress(MOC_TOKEN_KEY);
    address staking = IRegistryProbe(address(registry)).getAddress(MOC_STAKING_MACHINE_KEY);
    uint256 totalSupply = IERC20Probe(token).totalSupply();
    uint256 preVoteExpirationTimeDelta = IRegistryProbe(address(registry)).getUint(
      PRE_VOTE_EXPIRATION_TIME_DELTA_KEY
    );
    uint256 votingTimeDelta = IRegistryProbe(address(registry)).getUint(VOTING_TIME_DELTA_KEY);

    _setStake(token, staking, address(0x1001), totalSupply / 20);
    vm.prank(address(0x1001));
    IVotingMachineProbe(votingMachineProxy).preVote(proposal);

    _setStake(token, staking, address(0x1002), totalSupply / 20);
    vm.prank(address(0x1002));
    IVotingMachineProbe(votingMachineProxy).preVote(proposal);

    vm.warp(block.timestamp + preVoteExpirationTimeDelta + 1);
    IVotingMachineProbe(votingMachineProxy).preVoteStep();

    _setStake(token, staking, address(0x1003), totalSupply / 5);
    vm.prank(address(0x1003));
    IVotingMachineProbe(votingMachineProxy).vote(true);

    vm.warp(block.timestamp + votingTimeDelta + 1);
    IVotingMachineProbe(votingMachineProxy).voteStep();

    assertEq(IVotingMachineProbe(votingMachineProxy).getState(), 2);
  }

  function _setStake(address token, address staking, address account, uint256 amount) internal {
    deal(token, account, amount);
    vm.startPrank(account);
    IERC20Probe(token).approve(staking, amount);
    IStakingProbe(staking).deposit(amount);
    vm.stopPrank();
  }

  function _executeChanger() internal {
    require(
      _loadAddress(votingMachineProxy, IMPLEMENTATION_SLOT) != newVotingMachineImplementation,
      "new implementation must differ from current"
    );

    VotingMachineUpgradeProposal changer = new VotingMachineUpgradeProposal(
      votingMachineProxy,
      registry,
      IUpgradeDelegator(upgradeDelegator),
      newVotingMachineImplementation,
      uint248(acceptedStepPriorityTimeDelta)
    );

    IGovernor governor = IGovernor(IGoverned(upgradeDelegator).governor());
    address governorOwner = IOwnableLike(address(governor)).owner();

    vm.prank(governorOwner);
    governor.executeChange(IChangeContract(address(changer)));
  }

  function _deployFromArtifact(string memory artifactPath) internal returns (address deployed) {
    bytes memory bytecode = vm.getCode(artifactPath);
    require(bytecode.length != 0, "artifact bytecode is empty");
    assembly ("memory-safe") {
      deployed := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    require(deployed != address(0), "deployment failed");
  }
}
