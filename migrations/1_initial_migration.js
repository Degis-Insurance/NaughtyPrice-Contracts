const Migrations = artifacts.require("Migrations");
const fs = require("fs");

module.exports = function (deployer, network, accounts) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  deployer.deploy(Migrations);

  addressList[network].deployerAddress = accounts[0];
};
