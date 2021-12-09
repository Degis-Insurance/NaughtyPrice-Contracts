const PolicyCore = artifacts.require("PolicyCore");

const fs = require("fs");

module.exports = async function (deployer, network, accounts) {
  // Read the addressList
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  const mockUSD_address = addressList[network].MockUSD;
  const factory_address = addressList[network].NaughtyFactory;
  const pricegetter_address = addressList[network].PriceGetter;

  // Deployment
  await deployer.deploy(
    PolicyCore,
    mockUSD_address,
    factory_address,
    pricegetter_address
  );

  // Store the address
  addressList[network].PolicyCore = PolicyCore.address;
  // addressList[network].deployerAddress = accounts[0];
  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
