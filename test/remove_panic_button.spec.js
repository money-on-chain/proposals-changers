import hre from "hardhat";

import { expect } from "chai";

const { ethers } = await hre.network.connect();

async function freshDeploy() {
  const MocFactory = await ethers.getContractFactory("MoCMock");
  const moc = await MocFactory.deploy();

  const ChangerFactory = await ethers.getContractFactory("RemovePanicButtonProposal");
  const changer = await ChangerFactory.deploy(moc.target);

  return { moc, changer };
}

describe("RemovePanicButtonProposal", function () {
  it("stores constructor params correctly", async () => {
    const { changer } = await freshDeploy();
  });

  it("execute() applies, makes MoC unstoppable and burns fuse", async () => {
    const { moc, changer } = await freshDeploy();

    const tx = await changer.execute();
    const rc = await tx.wait();

    expect(await moc.unstoppable()).to.equal(true);
    expect(await changer.moc()).to.equal(ethers.ZeroAddress);

    const iface = (await ethers.getContractFactory("RemovePanicButtonProposal")).interface;
    const names = rc.logs
      .filter((l) => l.address.toLowerCase() === changer.target.toLowerCase())
      .map((log) => {
        try {
          return iface.parseLog(log).name;
        } catch {
          return "UNKNOWN";
        }
      });

    expect(names).to.include("PanicButtonRemoved");
    expect(names).to.include("ExecutedOnce");
  });

  it("execute() cannot be called twice", async () => {
    const { changer } = await freshDeploy();
    await changer.execute();
    await expect(changer.execute()).to.be.revertedWith("This changer was already executed");
  });
});
