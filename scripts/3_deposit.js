const avax301 = "0x573209A4eE09D585A856463154701F9B511ECCeF";
const pairAddress = "0x38a7477A88a70c3f6a622CC99a59c32C91488b0E";

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
