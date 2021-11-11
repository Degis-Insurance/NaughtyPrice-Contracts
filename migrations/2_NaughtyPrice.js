const NaughtyFactory = artifacts.require("NaughtyFactory");
const USDT = artifacts.require("USDT");
const NaughtyRouter = artifacts.require("NaughtyRouter");
const PolicyCore = artifacts.require("PolicyCore");
const NaughtyLibrary = artifacts.require("NaughtyLibrary");

const deployerAddress = "0x5a9FD75810Ed1176eBba30e719f0a30855aef6eb";

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
