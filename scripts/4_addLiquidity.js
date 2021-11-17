const tokenAddress = "0xaA723736738cabA6c1B4DF30325785D1D7805017";
const pairAddress = "0x4fd9E48afE3D0dfe4914E4a5f625bEb0d5F207fa";

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

    const policy = await PolicyToken.at(tokenAddress);

    // 添加20-20的流动性
    await policy.approve(router.address, web3.utils.toWei("40", "ether"), {
      from: mainAccount,
    });

    await usdt.approve(router.address, web3.utils.toWei("40", "ether"), {
      from: mainAccount,
    });

    let date = new Date().getTime();
    date = parseInt(date / 1000);
    console.log("now:", date);

    await router.setPolicyCore(core.address, { from: mainAccount });

    const tx = await router.addLiquidity(
      tokenAddress,
      usdt.address,
      web3.utils.toWei("40", "ether"),
      web3.utils.toWei("40", "ether"),
      web3.utils.toWei("10", "ether"),
      web3.utils.toWei("10", "ether"),
      mainAccount,
      date + 6000,
      { from: mainAccount }
    );
    console.log(tx.tx);

    const pair = await NaughtyPair.at(pairAddress);
    const tx2 = await pair.getReserves();

    console.log(parseInt(tx2[0]) / 1e18, parseInt(tx2[1] / 1e18));

    callback(true);
  } catch (err) {
    callback(err);
  }
};
