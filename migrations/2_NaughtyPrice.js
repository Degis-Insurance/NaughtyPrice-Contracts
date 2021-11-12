const NaughtyFactory = artifacts.require("NaughtyFactory");
const USDT = artifacts.require("USDT");
const NaughtyRouter = artifacts.require("NaughtyRouter");
const PolicyCore = artifacts.require("PolicyCore");
const NaughtyLibrary = artifacts.require("NaughtyLibrary");

const deployerAddress = "0xeFcbFe29c8cE02Dc1C4c2C3baacd9D7F60f5311B";

/**
 * @dev Deploy: USDT(for test, mainnet will have a fixed address)
 *              NaughtyRouter(for swapping tokens)
 *              NaughtyFactory(for deploying tokens and pairs)
 *              PolicyCore(for core logic of NaughtyPrice)
 *
 */
module.exports = async function (deployer) {
  await deployer.deploy(USDT);

  await deployer.deploy(NaughtyFactory, deployerAddress, USDT.address);

  await deployer.deploy(NaughtyLibrary);
  await deployer.link(NaughtyLibrary, NaughtyRouter);
  await deployer.deploy(NaughtyRouter, USDT.address, NaughtyFactory.address);

  await deployer.deploy(
    PolicyCore,
    USDT.address,
    NaughtyFactory.address,
    NaughtyRouter.address
  );
};
