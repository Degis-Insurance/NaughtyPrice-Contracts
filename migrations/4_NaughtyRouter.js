const NaughtyRouter = artifacts.require("NaughtyRouter");
const NaughtyLibrary = artifacts.require("NaughtyLibrary");

const fs = require("fs");

module.exports = async function (deployer, network) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  const buyerToken_add = addressList.BuyerToken;
  const factory_add = addressList.NaughtyFactory;

  await deployer.deploy(NaughtyLibrary);
  await deployer.link(NaughtyLibrary, NaughtyRouter);

  await deployer.deploy(NaughtyRouter, factory_add, buyerToken_add);

  addressList.NaughtyRouter = NaughtyRouter.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
