const tokenName = "BTC100L202101";

const USDT = artifacts.require("USDT");

const usd_address = "0x4379a39c8Bd46D651eC4bdA46C32E2725b217860";

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

    await core.addStablecoin(usd_address, { from: mainAccount });

    let now = new Date().getTime();
    now = parseInt(now / 1000);

    const tx = await core.deployPool(tokenName, usd_address, now + 300000, {
      from: mainAccount,
    });
    console.log(tx.tx);

    const ad = await core.findAddressbyName(tokenName, {
      from: mainAccount,
    });

    const pairAddress = await factory.getPairAddress(ad, usd_address, {
      from: mainAccount,
    });
    console.log("Pair address:", pairAddress);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
