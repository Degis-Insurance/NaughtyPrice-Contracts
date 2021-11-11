const avax301 = "0x971720B186F14e806F57658FdE1aC0e0D8b7259e";
const pairAddress = "0x4b321F59a12A6f61c3343d1f32097dD3eF6c690d";

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
