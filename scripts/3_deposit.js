const tokenName = "ETH_2000_L_202101";

const USDT = artifacts.require("USDT");
const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");

const fs = require("fs");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];

    const addressList = JSON.parse(fs.readFileSync("address.json"));

    const usdt = await USDT.at(addressList.USDT);
    console.log("USDT address:", usdt.address);

    const factory = await NaughtyFactory.at(addressList.NaughtyFactory);
    console.log("", factory.address);

    const core = await PolicyCore.at(addressList.PolicyCore);
    console.log(core.address);

    const address = await core.findAddressbyName(tokenName, {
      from: mainAccount,
    });
    console.log(address);

    const pairAddress = await factory.getPairAddress(address, usdt.address, {
      from: mainAccount,
    });
    console.log("Pair address:", pairAddress);

    const balance = await usdt.balanceOf(mainAccount);
    console.log("user balance:", parseInt(balance) / 1e18);

    await usdt.approve(core.address, web3.utils.toWei("200", "ether"), {
      from: mainAccount,
    });

    // 抵押100usd  铸造100 policy token
    const deposit_tx = await core.deposit(
      tokenName,
      usdt.address,
      web3.utils.toWei("100", "ether"),
      { from: mainAccount }
    );
    console.log(deposit_tx.tx);

    const delegate_deposit = await core.delegateDeposit(
      tokenName,
      usdt.address,
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

    callback(true);
  } catch (err) {
    callback(err);
  }
};
