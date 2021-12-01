const tokenName = "BTC_40000_L_202101";
const usd_address = "0x93424a368464763b244b761CBA4812D33B5e2f0b";

const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");
const NaughtyRouter = artifacts.require("NaughtyRouter");
const USD = artifacts.require("USDT");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];

    const factory = await NaughtyFactory.deployed();
    console.log(factory.address);

    const core = await PolicyCore.deployed();
    console.log(core.address);

    const router = await NaughtyRouter.deployed();
    console.log(router.address);

    // This is for local
    const usdt = await USD.at(usd_address);

    await core.addStablecoin(usdt.address, { from: mainAccount });

    let now = new Date().getTime();
    now = parseInt(now / 1000);

    const tx = await core.deployPool(tokenName, usdt.address, now + 300000, {
      from: mainAccount,
    });
    console.log(tx.tx);

    const address = await core.findAddressbyName(tokenName, {
      from: mainAccount,
    });

    const pairAddress = await factory.getPairAddress(address, usdt.address, {
      from: mainAccount,
    });
    console.log("Pair address:", pairAddress);

    await router.setPolicyCore(core.address, { from: mainAccount });

    callback(true);
  } catch (err) {
    callback(err);
  }
};
