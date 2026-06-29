import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("HardeningIIModule", (m) => {
  const mocV1Proxy = m.getParameter("mocV1Proxy");
  const mocStateV1Proxy = m.getParameter("mocStateV1Proxy");
  const mocExchangeV1Proxy = m.getParameter("mocExchangeV1Proxy");
  const mocInrateV1Proxy = m.getParameter("mocInrateV1Proxy");
  const mocBProxManagerV1Proxy = m.getParameter("mocBProxManagerV1Proxy");
  const rifBucketProxy = m.getParameter("rifBucketProxy");
  const docBucketProxy = m.getParameter("docBucketProxy");
  const upgradeDelegatorMoc = m.getParameter("upgradeDelegatorMoc");

  // Deploy new MoC V1 implementations
  const newMocV1Implementation = m.contract("DeployableMoC", [], {
    id: "MoCImplementation",
  });

  const newMocStateV1Implementation = m.contract("DeployableMoCState", [], {
    id: "MoCStateImplementation",
  });

  const newMocExchangeV1Implementation = m.contract("DeployableMoCExchange", [], {
    id: "MoCExchangeImplementation",
  });

  const newMocInrateV1Implementation = m.contract("DeployableMoCInrate", [], {
    id: "MoCInrateImplementation",
  });

  const newMocBProxManagerV1Implementation = m.contract("DeployableMoCBProxManager", [], {
    id: "MoCBProxManagerImplementation",
  });

  // Deploy new MocCARC20 implementations for rif and doc buckets
  const newRifBucketImplementation = m.contract("DeployableMocCARC20", [], {
    id: "RifBucketImplementation",
  });

  const newDocBucketImplementation = m.contract("DeployableMocCARC20", [], {
    id: "DocBucketImplementation",
  });

  // Deploy the HardeningII changer
  const changer = m.contract("HardeningII", [
    mocV1Proxy,
    mocStateV1Proxy,
    mocExchangeV1Proxy,
    mocInrateV1Proxy,
    mocBProxManagerV1Proxy,
    rifBucketProxy,
    docBucketProxy,
    upgradeDelegatorMoc,
    newMocV1Implementation,
    newMocStateV1Implementation,
    newMocExchangeV1Implementation,
    newMocInrateV1Implementation,
    newMocBProxManagerV1Implementation,
    newRifBucketImplementation,
    newDocBucketImplementation,
  ]);

  return {
    newMocV1Implementation,
    newMocStateV1Implementation,
    newMocExchangeV1Implementation,
    newMocInrateV1Implementation,
    newMocBProxManagerV1Implementation,
    newRifBucketImplementation,
    newDocBucketImplementation,
    changer,
  };
});
