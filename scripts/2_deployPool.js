const tokenName = "BTC100L202101";

const USDT = artifacts.require("USDT");

const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];
    const usdt = await USDT.deployed();

    const factory = await NaughtyFactory.deployed();
    console.log(factory.address);

    const core = await PolicyCore.deployed();
    console.log(core.address);

    let now = new Date().getTime();
    now = parseInt(now / 1000);

    const tx = await core.deployPool(tokenName, usdt.address, now + 500, {
      from: mainAccount,
    });
    console.log(tx.tx);

    const ad = await core.findAddressbyName(tokenName, {
      from: mainAccount,
    });

    const pairAddress = await factory.getPairAddress(ad, usdt.address, {
      from: mainAccount,
    });
    console.log("AVAX30-202102-usdt Pair address:", pairAddress);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
