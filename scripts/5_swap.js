const USDT = artifacts.require("USDT");
const PolicyCore = artifacts.require("PolicyCore");
const PolicyToken = artifacts.require("PolicyToken");
const NaughtyFactory = artifacts.require("NaughtyFactory");
const NaughtyPair = artifacts.require("NaughtyPair");
const NaughtyRouter = artifacts.require("NaughtyRouter");

const usd_address = "0xAc141573202C0c07DFE432EAa1be24a9cC97d358";
const policyTokenName = "BTC_40000_L_202101";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];

    //合约实例
    const usdt = await USDT.at(usd_address);

    const factory = await NaughtyFactory.deployed();
    console.log("factory address", factory.address);

    const core = await PolicyCore.deployed();
    console.log("core address", core.address);

    const router = await NaughtyRouter.deployed();
    console.log("router address", router.address);

    const tokenAddress = await core.findAddressbyName(policyTokenName, {
      from: mainAccount,
    });
    console.log("policy token address in core:", tokenAddress);
    const policy = await PolicyToken.at(tokenAddress);

    const pairAddress = await factory.getPairAddress(
      tokenAddress,
      usdt.address,
      {
        from: mainAccount,
      }
    );
    console.log("Pair address:", pairAddress);
    const pair = await NaughtyPair.at(pairAddress);
    console.log(pair.address);

    // 用户代币余额
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

    // approve
    await policy.approve(router.address, web3.utils.toWei("20000", "ether"), {
      from: mainAccount,
    });

    await usdt.approve(router.address, web3.utils.toWei("20000", "ether"), {
      from: mainAccount,
    });

    //交易发生前的reserve
    const reserve1 = await pair.getReserves();
    console.log(
      "Reserve0 Before:",
      parseInt(reserve1[0]) / 1e18,
      "Reserve1 Before:",
      parseInt(reserve1[1]) / 1e18
    );

    // await pair.sync({ from: mainAccount });

    console.log(
      "\n--------------------swap tokens for exact tokens ---------------------------\n"
    );

    // 买
    const tx = await router.swapExactTokensforTokens(
      web3.utils.toWei("4", "ether"),
      web3.utils.toWei("2", "ether"),
      usdt.address,
      tokenAddress,
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

    console.log("usdt balance after:", parseInt(usdt_after));
    console.log("policy after:", parseInt(policy_after));

    const reserve2 = await pair.getReserves();

    console.log(
      "Reserve0 after first swap(buy):",
      parseInt(reserve2[0]) / 1e18,
      "Reserve1 after first swap(buy):",
      parseInt(reserve2[1]) / 1e18
    );

    // 卖
    const tx3 = await router.swapExactTokensforTokens(
      web3.utils.toWei("1", "ether"),
      web3.utils.toWei("0.01", "ether"),
      tokenAddress,
      usdt.address,
      mainAccount,
      date + 6000,
      { from: mainAccount }
    );
    console.log(tx3.tx);

    const reserve3 = await pair.getReserves();

    console.log(
      "Reserve0 finally:",
      parseInt(reserve3[0]) / 1e18,
      "Reserve1 finally:",
      parseInt(reserve3[1]) / 1e18
    );

    callback(true);
  } catch (err) {
    callback(err);
  }
};
