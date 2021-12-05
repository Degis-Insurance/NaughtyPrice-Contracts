const PolicyCore = artifacts.require("PolicyCore");

const fs = require("fs");

module.exports = async function (deployer, network) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  const usd_rinkeby = addressList.USDT;
  const factory_add = addressList.NaughtyFactory;
  const pricegetter_add = addressList.PriceGetter;

  await deployer.deploy(PolicyCore, usd_rinkeby, factory_add, pricegetter_add);

  addressList.PolicyCore = PolicyCore.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
