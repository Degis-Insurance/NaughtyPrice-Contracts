const policyTokenName = "BTC_30000_L_202101";

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

    const addressList = JSON.parse(fs.readFileSync("address.json"));

    const usdt = await USDT.at(addressList.USDT);

    const factory = await NaughtyFactory.at(addressList.NaughtyFactory);
    console.log("factory address", factory.address);

    const core = await PolicyCore.at(addressList.PolicyCore);
    console.log("core address", core.address);

    const router = await NaughtyRouter.at(addressList.NaughtyRouter);
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

    // 添加20-20的流动性
    await policy.approve(router.address, web3.utils.toWei("400", "ether"), {
      from: mainAccount,
    });

    await usdt.approve(router.address, web3.utils.toWei("400", "ether"), {
      from: mainAccount,
    });

    let date = new Date().getTime();
    date = parseInt(date / 1000);
    console.log("now:", date);

    // Add liquidity
    const tx = await router.addLiquidity(
      tokenAddress,
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

    await usdt.approve(router.address, web3.utils.toWei("400", "ether"), {
      from: mainAccount,
    });
    await usdt.approve(core.address, web3.utils.toWei("400", "ether"), {
      from: mainAccount,
    });

    await policy.approve(router.address, web3.utils.toWei("400", "ether"), {
      from: mainAccount,
    });

    // Add liquidity only with stablecoin
    const deletx = await router.addLiquidityWithUSD(
      tokenAddress,
      usdt.address,
      web3.utils.toWei("20", "ether"),
      mainAccount,
      80,
      date + 6000,
      { from: mainAccount }
    );
    console.log(deletx.tx);

    const pair = await NaughtyPair.at(pairAddress);
    const tx2 = await pair.getReserves();

    console.log(
      "Reserve0:",
      parseInt(tx2[0]) / 1e18,
      "Reserve1:",
      parseInt(tx2[1] / 1e18)
    );

    const lptoken = await pair.balanceOf(mainAccount, { from: mainAccount });
    console.log("user lp token balanceL:", parseInt(lptoken / 1e18));

    await pair.approve(router.address, web3.utils.toWei("500", "ether"), {
      from: mainAccount,
    });

    const removetx = await router.removeLiquidity(
      tokenAddress,
      usdt.address,
      web3.utils.toWei("2", "ether"),
      web3.utils.toWei("1", "ether"),
      web3.utils.toWei("1", "ether"),
      mainAccount,
      date + 6000,
      { from: mainAccount }
    );

    const tx3 = await pair.getReserves();
    console.log(
      "Reserve0:",
      parseInt(tx3[0]) / 1e18,
      "Reserve1:",
      parseInt(tx3[1] / 1e18)
    );

    callback(true);
  } catch (err) {
    callback(err);
  }
};
