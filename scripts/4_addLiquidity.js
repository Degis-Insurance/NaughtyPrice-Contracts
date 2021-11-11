const avax301 = "0x971720B186F14e806F57658FdE1aC0e0D8b7259e";
const pairAddress = "0x4b321F59a12A6f61c3343d1f32097dD3eF6c690d";

const USDT = artifacts.require("USDT");
const PolicyCore = artifacts.require("PolicyCore");
const PolicyToken = artifacts.require("PolicyToken");
const NaughtyFactory = artifacts.require("NaughtyFactory");
const NaughtyPair = artifacts.require("NaughtyPair");
const NaughtyRouter = artifacts.require("NaughtyRouter");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];
    const usdt = await USDT.deployed();

    const factory = await NaughtyFactory.deployed();
    console.log("factory address", factory.address);

    const core = await PolicyCore.deployed();
    console.log("core address", core.address);

    const router = await NaughtyRouter.deployed();
    console.log("router address", router.address);

    const policy = await PolicyToken.at(avax301);

    await policy.approve(core.address, web3.utils.toWei("20", "ether"), {
      from: mainAccount,
    });

    await usdt.approve(core.address, web3.utils.toWei("20", "ether"), {
      from: mainAccount,
    });

    let date = new Date().getTime();
    const tx = await router.addLiquidity(
      avax301,
      usdt.address,
      web3.utils.toWei("20", "ether"),
      web3.utils.toWei("20", "ether"),
      web3.utils.toWei("10", "ether"),
      web3.utils.toWei("10", "ether"),
      mainAccount,
      date + 6000,
      { from: mainAccount }
    );

    console.log(tx.tx);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
