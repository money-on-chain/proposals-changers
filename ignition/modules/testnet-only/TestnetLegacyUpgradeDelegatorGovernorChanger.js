import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { batchModule } from "ignition-utils";

const TestnetLegacyUpgradeDelegatorGovernorChangerModule = buildModule(
  "TestnetLegacyUpgradeDelegatorGovernorChangerModule",
  (m) => {
    const changer = m.contract("TestnetLegacyUpgradeDelegatorGovernorChanger");
    return { changer };
  },
);

export default batchModule(TestnetLegacyUpgradeDelegatorGovernorChangerModule);
