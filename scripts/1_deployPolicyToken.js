// truffle exec scripts/1_deployPolicyToken.js --network fuji --token BTC --K 30000 --isCall 0 --round 202101

const PolicyCore = artifacts.require("PolicyCore");
const NaughtyFactory = artifacts.require("NaughtyFactory");

const fs = require("fs");

const args = require("minimist")(process.argv.slice(2));
const tokenName = args["token"];
const strikePrice = args["K"];
const isCall = args["isCall"];
const round = args["round"];

const nameisCall = isCall == 1 ? "H" : "L";
const policyTokenName =
  tokenName + "_" + strikePrice + "_" + nameisCall + "_" + round;
console.log("policy toke name: ", policyTokenName);

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const mainAccount = accounts[0];
    console.log("main account:", mainAccount);

    const addressList = JSON.parse(fs.readFileSync("address.json"));

    const core = await PolicyCore.at(addressList.fuji.PolicyCore);
    console.log("policyCore address:", core.address);

    const factory = await NaughtyFactory.at(addressList.fuji.NaughtyFactory);

    await factory.setPolicyCoreAddress(core.address, {
      from: mainAccount,
    });

    let now = new Date().getTime();
    now = parseInt(now / 1000);
    console.log("now timestamp:", now);

    const startTime = "1639915200"; //"12-19"
    const stopTime = "1640001600"; //"12-20"

    const boolisCall = isCall == 1 ? true : false;
    await core.deployPolicyToken(
      tokenName,
      boolisCall,
      web3.utils.toWei(strikePrice.toString(), "ether"),
      round,
      startTime,
      stopTime,
      {
        from: mainAccount,
      }
    );

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
