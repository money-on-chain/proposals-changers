import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

declare const LendingAndBorrowingV1Module: ReturnType<typeof buildModule>;

export default LendingAndBorrowingV1Module;
