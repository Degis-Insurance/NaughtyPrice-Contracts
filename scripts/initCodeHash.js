const NaughtyFactory = artifacts.require("NaughtyFactory");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];

    const factory = await NaughtyFactory.deployed();
    console.log("factory address", factory.address);

    const code_hash = await factory.INIT_CODE_HASH.call();

    console.log("init code hash", code_hash);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
