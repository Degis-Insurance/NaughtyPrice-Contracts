const tokenName = "BTC";
const strikePrice = "30000";
const round = 202101;
const policyTokenName = "BTC_30000_L_202101";

const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");

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
      false,
      web3.utils.toWei(strikePrice, "ether"),
      round,
      now + 300000,
      now + 300060,
      {
        from: mainAccount,
      }
    );

    console.log("new deployed policy token:", policyTokenAddress);

    const address = await core.findAddressbyName(policyTokenName, {
      from: mainAccount,
    });
    console.log("policy token address in core:", address);

    const name = await core.findNamebyAddress(address, { from: mainAccount });
    console.log("policy token name in core:", name);

    const info = await core.getPolicyTokenInfo(policyTokenName, {
      from: mainAccount,
    });
    console.log("policy token info:", info);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
