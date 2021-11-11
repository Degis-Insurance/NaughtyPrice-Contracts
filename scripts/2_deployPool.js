const avax301 = "0x573209A4eE09D585A856463154701F9B511ECCeF";

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

    const tx = await core.deployPool(avax301, { from: mainAccount });
    console.log(tx.tx);

    const pairAddress = await factory.getPairAddress(avax301, usdt.address, {
      from: mainAccount,
    });

    console.log("Pair address:", pairAddress);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
