const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");
const USDT = artifacts.require("USDT");

const fs = require("fs");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];

    console.log("main account:", mainAccount);
    const policyCore = await PolicyCore.deployed();

    console.log("policyCore address:", policyCore.address);

    const factory = await NaughtyFactory.deployed();
    const usdt = await factory.USDT.call();
    console.log("usdt in factory:", usdt);

    await factory.setPolicyCoreAddress(policyCore.address, {
      from: mainAccount,
    });

    const policyTokenAddress = await policyCore.deployPolicyToken(
      "AVAX30-202101",
      { from: mainAccount }
    );

    console.log(policyTokenAddress);

    const ad = await policyCore.findAddressbyName("AVAX30-202101");
    console.log("policy token address:", ad);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
