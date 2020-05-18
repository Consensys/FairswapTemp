const Factory = artifacts.require("ExchangeFactory");
const TestToken = artifacts.require("TestToken");

module.exports = async (deployer) => {
  await deployer.deploy(TestToken);
  let lien = await TestToken.new();
  await deployer.deploy(Factory, lien.address);
};