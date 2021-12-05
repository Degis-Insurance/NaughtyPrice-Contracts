const PriceGetter = artifacts.require("PriceGetter");

const fs = require("fs");

module.exports = async function (deployer, network) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  await deployer.deploy(PriceGetter);

  addressList.PriceGetter = PriceGetter.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
