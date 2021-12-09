const NaughtyRouter = artifacts.require("NaughtyRouter");
const NaughtyLibrary = artifacts.require("NaughtyLibrary");

const fs = require("fs");

module.exports = async function (deployer, network, accounts) {
  // Read the addressList
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  const buyerToken_address = addressList.ref.BuyerToken;
  const factory_address = addressList[network].NaughtyFactory;

  // Deployment
  await deployer.deploy(NaughtyLibrary);
  await deployer.link(NaughtyLibrary, NaughtyRouter);
  await deployer.deploy(NaughtyRouter, factory_address, buyerToken_address);

  // Store the address
  addressList[network].NaughtyRouter = NaughtyRouter.address;
  addressList[network].NaughtyLibrary = NaughtyLibrary.address;
  // addressList[network].deployerAddress = accounts[0];
  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
