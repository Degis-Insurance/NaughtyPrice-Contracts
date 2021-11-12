const avax301 = "0xB489eBF43f10902F1A7Db2BEB5De4B7e82983057";
const pairAddress = "0xCb417b5831D4D2a3818c7aEce27d6a8F624d4750";

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

    await usdt.approve(core.address, web3.utils.toWei("100", "ether"), {
      from: mainAccount,
    });

    const deposit_tx = await core.deposit(
      avax301,
      web3.utils.toWei("100", "ether"),
      { from: mainAccount }
    );
    console.log(deposit_tx.tx);

    const redeem_tx = await core.redeem(
      avax301,
      web3.utils.toWei("20", "ether"),
      { from: mainAccount }
    );
    console.log(redeem_tx.tx);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
