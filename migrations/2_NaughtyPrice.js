const NaughtyFactory = artifacts.require("NaughtyFactory");
const USDT = artifacts.require("USDT");
const NaughtyRouter = artifacts.require("NaughtyRouter");
const PolicyCore = artifacts.require("PolicyCore");
const NaughtyLibrary = artifacts.require("NaughtyLibrary");
const PriceGetter = artifacts.require("PriceGetter");

const degis = "0x77E4DC6B670B618dfE00fea8AD36d445a48D0181";

const buyerToken = "0x4F99CE3294E7e650CEBb8f94e6cD7C629C4f494D";

const usd_rinkeby = "0x4379a39c8Bd46D651eC4bdA46C32E2725b217860";

const fs = require("fs");
/**
 * @dev Deploy: USDT(for test, mainnet will have a fixed address)
 *              NaughtyRouter(for swapping tokens)
 *              NaughtyFactory(for deploying tokens and pairs)
 *              PolicyCore(for core logic of NaughtyPrice)
 *
 */
module.exports = async function (deployer) {
  // await deployer.deploy(USDT);

  await deployer.deploy(PriceGetter);

  await deployer.deploy(NaughtyFactory, degis);

  await deployer.deploy(NaughtyLibrary);
  await deployer.link(NaughtyLibrary, NaughtyRouter);
  await deployer.deploy(NaughtyRouter, NaughtyFactory.address, buyerToken);

  await deployer.deploy(
    PolicyCore,
    usd_rinkeby,
    NaughtyFactory.address,
    PriceGetter.address
  );

  const addressList = {
    PriceGetter: PriceGetter.address,
    NaughtyFactory: NaughtyFactory.address,
    NaughtyRouter: NaughtyRouter.address,
    PolicyCore: PolicyCore.address,
  };

  const data = JSON.stringify(addressList);

  fs.writeFile("address.json", data, (err) => {
    if (err) {
      throw err;
    }
  });

  // await deployer.deploy(
  //   NaughtyProxy,
  //   PolicyCore.address,
  //   NaughtyRouter.address
  // );
};
