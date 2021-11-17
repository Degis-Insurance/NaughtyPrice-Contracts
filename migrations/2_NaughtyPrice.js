const NaughtyFactory = artifacts.require("NaughtyFactory");
const USDT = artifacts.require("USDT");
const NaughtyRouter = artifacts.require("NaughtyRouter");
const PolicyCore = artifacts.require("PolicyCore");
const NaughtyLibrary = artifacts.require("NaughtyLibrary");
const PriceGetter = artifacts.require("PriceGetter");
const NaughtyProxy = artifacts.require("NaughtyProxy");

/**
 * @dev Deploy: USDT(for test, mainnet will have a fixed address)
 *              NaughtyRouter(for swapping tokens)
 *              NaughtyFactory(for deploying tokens and pairs)
 *              PolicyCore(for core logic of NaughtyPrice)
 *
 */
module.exports = async function (deployer) {
  await deployer.deploy(USDT);

  await deployer.deploy(PriceGetter);

  await deployer.deploy(NaughtyFactory);

  await deployer.deploy(NaughtyLibrary);
  await deployer.link(NaughtyLibrary, NaughtyRouter);
  await deployer.deploy(NaughtyRouter, NaughtyFactory.address);

  await deployer.deploy(
    PolicyCore,
    USDT.address,
    NaughtyFactory.address,
    NaughtyRouter.address,
    PriceGetter.address
  );

  // await deployer.deploy(
  //   NaughtyProxy,
  //   PolicyCore.address,
  //   NaughtyRouter.address
  // );
};
