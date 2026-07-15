import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("SetMocSwapperPathModule", (m) => {
  const mocSwapper = m.getParameter("mocSwapper");
  const rifToken = m.getParameter("rifToken");
  const mocToken = m.getParameter("mocToken");

  const rifToMocIntermediateTokens = m.getParameter("rifToMocIntermediateTokens");
  const rifToMocFees = m.getParameter("rifToMocFees");

  const mocToRifIntermediateTokens = m.getParameter("mocToRifIntermediateTokens");
  const mocToRifFees = m.getParameter("mocToRifFees");

  const changer = m.contract("SetMocSwapperPath", [
    mocSwapper,
    rifToken,
    mocToken,
    rifToMocIntermediateTokens,
    rifToMocFees,
    mocToRifIntermediateTokens,
    mocToRifFees,
  ]);

  return { changer };
});
