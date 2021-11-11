const avax301 = "0x573209A4eE09D585A856463154701F9B511ECCeF";
const pairAddress = "0x38a7477A88a70c3f6a622CC99a59c32C91488b0E";

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

    await policy.approve(router.address, web3.utils.toWei("20", "ether"), {
      from: mainAccount,
    });

    await usdt.approve(router.address, web3.utils.toWei("20", "ether"), {
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
