const Factory = artifacts.require("ExchangeFactory");
const TestToken = artifacts.require("TestToken");

module.exports = function(deployer) {
  
  deployer.deploy(TestToken).then(function (lienToken){
    deployer.deploy(Factory, lienToken.address);
  })
};