const NaughtyFactory = artifacts.require("NaughtyFactory");

const fs = require("fs");

module.exports = async function (deployer, network, accounts) {
  // Read the addressList
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  const degis_address = addressList.ref.DegisToken;

  // Deployment
  await deployer.deploy(NaughtyFactory, degis_address);

  // Store the address
  addressList[network].NaughtyFactory = NaughtyFactory.address;
  // addressList[network].deployerAddress = accounts[0];
  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
