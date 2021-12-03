const NaughtyFactory = artifacts.require("NaughtyFactory");
const USDT = artifacts.require("USDT");
const NaughtyRouter = artifacts.require("NaughtyRouter");
const PolicyCore = artifacts.require("PolicyCore");
const NaughtyLibrary = artifacts.require("NaughtyLibrary");
const PriceGetter = artifacts.require("PriceGetter");

const degis = "0x6d3036117de5855e1ecd338838FF9e275009eAc2";

const buyerToken = "0x876431DAE3c10273F7B58567419eb40157CcA9Eb";

const usd_rinkeby = "0xAc141573202C0c07DFE432EAa1be24a9cC97d358";

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
};
