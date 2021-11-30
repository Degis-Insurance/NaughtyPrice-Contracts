const NaughtyFactory = artifacts.require("NaughtyFactory");
const USDT = artifacts.require("USDT");
const NaughtyRouter = artifacts.require("NaughtyRouter");
const PolicyCore = artifacts.require("PolicyCore");
const NaughtyLibrary = artifacts.require("NaughtyLibrary");
const PriceGetter = artifacts.require("PriceGetter");

const degis = "0x0C970444856f143728e791fbfC3b5f6AD7f417Dd";

const buyerToken = "0xA5186070ef5BFD5Ea84B7AaA11D380b759443959";

const usd_rinkeby = "0x93424a368464763b244b761CBA4812D33B5e2f0b";

const fs = require("fs");
/**
 * @dev Deploy: USDT(for test, mainnet will have a fixed address)
 *              NaughtyRouter(for swapping tokens)
 *              NaughtyFactory(for deploying tokens and pairs)
 *              PolicyCore(for core logic of NaughtyPrice)
 *
 */
module.exports = async function (deployer, network) {
  if (network.startsWith("development")) {
    await deployer.deploy(USDT);
  }

  await deployer.deploy(PriceGetter);

  await deployer.deploy(NaughtyFactory, degis);

  await deployer.deploy(NaughtyLibrary);
  await deployer.link(NaughtyLibrary, NaughtyRouter);
  await deployer.deploy(NaughtyRouter, NaughtyFactory.address, buyerToken);
  if (network.startsWith("rinkeby")) {
    await deployer.deploy(
      PolicyCore,
      usd_rinkeby,
      NaughtyFactory.address,
      PriceGetter.address
    );
  } else if (network.startsWith("development")) {
    await deployer.deploy(
      PolicyCore,
      USDT.address,
      NaughtyFactory.address,
      PriceGetter.address
    );
  }

  if (network.startsWith("rinkeby")) {
    const addressList = {
      PriceGetter: PriceGetter.address,
      NaughtyFactory: NaughtyFactory.address,
      NaughtyRouter: NaughtyRouter.address,
      PolicyCore: PolicyCore.address,
    };

    const data = JSON.stringify(addressList, null, "\t");

    fs.writeFile("address.json", data, (err) => {
      if (err) {
        throw err;
      }
    });
  }

  // await deployer.deploy(
  //   NaughtyProxy,
  //   PolicyCore.address,
  //   NaughtyRouter.address
  // );
};
