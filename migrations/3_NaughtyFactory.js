const NaughtyFactory = artifacts.require("NaughtyFactory");

const fs = require("fs");

module.exports = async function (deployer, network) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));
  const degis_add = addressList.DEGIS;

  await deployer.deploy(NaughtyFactory, degis_add);

  addressList.NaughtyFactory = NaughtyFactory.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
