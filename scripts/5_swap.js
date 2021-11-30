const tokenAddress = "0xAA552751aEF4DE9feEB4f875E7Ed3170D03C9c41";
const pairAddress = "0x402b1096bF14eD442A132cb66057b451Bac24252";
const usdAddress = "0x93424a368464763b244b761CBA4812D33B5e2f0b";

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
    const usdt = await USDT.at(usdAddress);

    const factory = await NaughtyFactory.deployed();
    console.log("factory address", factory.address);

    const core = await PolicyCore.deployed();
    console.log("core address", core.address);

    const router = await NaughtyRouter.deployed();
    console.log("router address", router.address);

    const policy = await PolicyToken.at(tokenAddress);

    const usdt_before = await usdt.balanceOf(mainAccount, {
      from: mainAccount,
    });
    const policy_before = await policy.balanceOf(mainAccount, {
      from: mainAccount,
    });

    console.log("usdt balance before:", parseInt(usdt_before) / 1e18);
    console.log("policy_before:", parseInt(policy_before) / 1e18);

    let date = new Date().getTime();
    date = parseInt(date / 1000);

    await policy.approve(router.address, web3.utils.toWei("20000", "ether"), {
      from: mainAccount,
    });

    await usdt.approve(router.address, web3.utils.toWei("20000", "ether"), {
      from: mainAccount,
    });

    const pair = await NaughtyPair.at(pairAddress);

    const reserve1 = await pair.getReserves();

    console.log(
      "Reserve0",
      parseInt(reserve1[0]) / 1e18,
      "Reserve1:",
      parseInt(reserve1[1]) / 1e18
    );

    await pair.sync({ from: mainAccount });

    // 用最多20个policy token 换10个usdt出来
    const tx = await router.swapTokensforExactTokens(
      web3.utils.toWei("20", "ether"),
      web3.utils.toWei("10", "ether"),
      tokenAddress,
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

    console.log("usdt balance after:", parseInt(usdt_after) / 1e18);
    console.log("policy after:", parseInt(policy_after) / 1e18);

    const reserve2 = await pair.getReserves();

    console.log(
      "Reserve0:",
      parseInt(reserve2[0]) / 1e18,
      "Reserve1:",
      parseInt(reserve2[1]) / 1e18
    );

    const tx3 = await router.swapExactTokensforTokens(
      web3.utils.toWei("10", "ether"),
      web3.utils.toWei("2", "ether"),
      usdt.address,
      tokenAddress,
      mainAccount,
      date + 6000,
      { from: mainAccount }
    );
    console.log(tx3.tx);

    const reserve3 = await pair.getReserves();

    console.log(
      "Reserve0:",
      parseInt(reserve3[0]) / 1e18,
      "Reserve1:",
      parseInt(reserve3[1]) / 1e18
    );

    callback(true);
  } catch (err) {
    callback(err);
  }
};
