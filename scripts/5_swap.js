const avax301 = "0xB489eBF43f10902F1A7Db2BEB5De4B7e82983057";
const pairAddress = "0xCb417b5831D4D2a3818c7aEce27d6a8F624d4750";

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

    const usdt_before = await usdt.balanceOf(mainAccount, {
      from: mainAccount,
    });
    const policy_before = await policy.balanceOf(mainAccount, {
      from: mainAccount,
    });

    console.log("usdt balance before:", parseInt(usdt_before) / 1e18);
    console.log("policy_before:", parseInt(policy_before) / 1e18);

    let date = new Date().getTime();

    await policy.approve(router.address, web3.utils.toWei("21", "ether"), {
      from: mainAccount,
    });

    // 用最多21个policy token 换10个usdt出来
    const tx = await router.swapTokensforExactTokens(
      web3.utils.toWei("21", "ether"),
      web3.utils.toWei("10", "ether"),
      avax301,
      usdt.address,
      mainAccount,
      date + 6000,
      { from: mainAccount }
    );
    console.log(tx.tx);

    const usdt_after = await usdt.balanceOf(mainAccount, {
      from: mainAccount,
    });
    const policy_after = await policy.balanceOf(mainAccount, {
      from: mainAccount,
    });

    console.log("usdt balance before:", parseInt(usdt_after) / 1e18);
    console.log("policy_before:", parseInt(policy_after) / 1e18);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
