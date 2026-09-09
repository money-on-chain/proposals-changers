import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { batchModule } from "ignition-utils";

const MIP263701Module = buildModule("MIP263701Module", (m) => {
  const mocProxy = m.getParameter("mocProxy");
  const mocStateProxy = m.getParameter("mocStateProxy");
  const mocInrateProxy = m.getParameter("mocInrateProxy");
  const coinerProxy = m.getParameter("coinerProxy");
  const mocUpgradeDelegator = m.getParameter("mocUpgradeDelegator");
  const flowUpgradeDelegator = m.getParameter("flowUpgradeDelegator");
  const anchorBlockNumber = m.getParameter("anchorBlockNumber");
  const anchorTimestamp = m.getParameter("anchorTimestamp");

  const mocImplementation = m.contract("DeployableMoC", [], {
    id: "MoCImplementation",
  });
  const mocStateImplementation = m.contract("DeployableMoCState", [], {
    id: "MoCStateImplementation",
  });
  const mocInrateImplementation = m.contract("DeployableMoCInrate", [], {
    id: "MoCInrateImplementation",
  });
  const coinerImplementation = m.contract("DeployableCoiner", [], {
    id: "CoinerImplementation",
  });
  const changer = m.contract("MIP263701UseTimestamps", [
    mocProxy,
    mocStateProxy,
    mocInrateProxy,
    coinerProxy,
    mocUpgradeDelegator,
    flowUpgradeDelegator,
    mocImplementation,
    mocStateImplementation,
    mocInrateImplementation,
    coinerImplementation,
    anchorBlockNumber,
    anchorTimestamp,
  ]);

  return { mocImplementation, mocStateImplementation, mocInrateImplementation, coinerImplementation, changer };
});

export default batchModule(MIP263701Module);
