const tokenName = "BTC_40000_L_202101";
const usd_address = "0x93424a368464763b244b761CBA4812D33B5e2f0b";

const policyTokenName = "BTC_40000_L_202101";

const USDT = artifacts.require("USDT");
const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];
    const usdt = await USDT.at(usd_address);

    const factory = await NaughtyFactory.deployed();
    console.log(factory.address);

    const core = await PolicyCore.deployed();
    console.log(core.address);

    console.log(usdt.address);

    const balance = await usdt.balanceOf(mainAccount);
    console.log("user balance:", parseInt(balance) / 1e18);

    await usdt.approve(core.address, web3.utils.toWei("200", "ether"), {
      from: mainAccount,
    });

    // 抵押100usd  铸造100 policy token
    const deposit_tx = await core.deposit(
      tokenName,
      usd_address,
      web3.utils.toWei("100", "ether"),
      { from: mainAccount }
    );
    console.log(deposit_tx.tx);

    const delegate_deposit = await core.delegateDeposit(
      tokenName,
      usd_address,
      web3.utils.toWei("100", "ether"),
      mainAccount,
      { from: mainAccount }
    );
    console.log(delegate_deposit.tx);

    // 取回20usd
    const redeem_tx = await core.redeem(
      tokenName,
      usdt.address,
      web3.utils.toWei("20", "ether"),
      { from: mainAccount }
    );
    console.log(redeem_tx.tx);

    const address = await core.findAddressbyName(policyTokenName, {
      from: mainAccount,
    });
    console.log("policy token address in core:", address);

    const pairAddress = await factory.getPairAddress(address, usd_address, {
      from: mainAccount,
    });
    console.log("Pair address:", pairAddress);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
