const tokenName = "BTC_30000_L_202101";

const usd_address = "0x4379a39c8Bd46D651eC4bdA46C32E2725b217860";

const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");
const NaughtyRouter = artifacts.require("NaughtyRouter");

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

    await core.addStablecoin(usd_address, { from: mainAccount });

    let now = new Date().getTime();
    now = parseInt(now / 1000);

    const tx = await core.deployPool(tokenName, usd_address, now + 300000, {
      from: mainAccount,
    });
    console.log(tx.tx);

    const address = await core.findAddressbyName(tokenName, {
      from: mainAccount,
    });

    const pairAddress = await factory.getPairAddress(address, usd_address, {
      from: mainAccount,
    });
    console.log("Pair address:", pairAddress);

    await router.setPolicyCore(core.address, { from: mainAccount });

    callback(true);
  } catch (err) {
    callback(err);
  }
};
