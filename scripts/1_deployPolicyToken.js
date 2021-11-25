const tokenName = "BTC100L202101";

const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");

const testAddress = "0x32eB34d060c12aD0491d260c436d30e5fB13a8Cd";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];
    console.log("main account:", mainAccount);

    const core = await PolicyCore.deployed();
    console.log("policyCore address:", core.address);

    const factory = await NaughtyFactory.deployed();

    await factory.setPolicyCoreAddress(core.address, {
      from: mainAccount,
    });

    let now = new Date().getTime();
    now = parseInt(now / 1000);
    console.log("now timestamp:", now);

    const policyTokenAddress = await core.deployPolicyToken(
      tokenName,
      testAddress,
      false,
      web3.utils.toWei("30", "ether"),
      now + 5000,
      now + 5600,
      {
        from: mainAccount,
      }
    );

    console.log("new deployed policy token:", policyTokenAddress);

    const address = await core.findAddressbyName(tokenName, {
      from: mainAccount,
    });
    console.log("policy token address in core:", address);

    const name = await core.findNamebyAddress(address, { from: mainAccount });
    console.log("policy token name in core:", name);

    const info = await core.getPolicyTokenInfo(tokenName, {
      from: mainAccount,
    });
    console.log("policy token info:", info);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
