// truffle exec scripts/2_deployPool.js --network fuji --name BTC_30000_L_202101

const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");
const NaughtyRouter = artifacts.require("NaughtyRouter");
const USD = artifacts.require("USDT");

const args = require("minimist")(process.argv.slice(2));
const tokenName = args["name"];

const fs = require("fs");

const startTime = "1639915200";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];

    const addressList = JSON.parse(fs.readFileSync("address.json"));

    const factory = await NaughtyFactory.at(addressList.fuji.NaughtyFactory);
    console.log(factory.address);

    const core = await PolicyCore.at(addressList.fuji.PolicyCore);
    console.log(core.address);

    // const router = await NaughtyRouter.at(addressList.fuji.NaughtyRouter);
    // console.log(router.address);

    const usdt = await USD.at(addressList.ref.MockUSD);
    // const hasAddedStablecoin = await core.isStablecoinAddress(usdt.address);
    // if (!hasAddedStablecoin) {
    //   await core.addStablecoin(usdt.address, { from: mainAccount });
    // }

    // let now = new Date().getTime();
    // now = parseInt(now / 1000);

    // await core.deployPool(tokenName, usdt.address, startTime, {
    //   from: mainAccount,
    // });

    const address = await core.findAddressbyName(tokenName, {
      from: mainAccount,
    });
    console.log("Token address:", address);

    const pairAddress = await factory.getPairAddress(address, usdt.address, {
      from: mainAccount,
    });
    console.log("Pair address:", pairAddress);

    // const coreinRouter = await router.policyCore.call();
    // if (coreinRouter != core.address) {
    //   await router.setPolicyCore(core.address, { from: mainAccount });
    // }

    callback(true);
  } catch (err) {
    callback(err);
  }
};
