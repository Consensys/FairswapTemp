const BoxExchange = artifacts.require("BoxExchange");
const TestToken = artifacts.require("TestToken");
const Factory = artifacts.require("ExchangeFactory");
let setting = async function(accounts)  {
    
    const [factory, buyer1, buyer2, seller1, seller2, LP1, LP2, buyer3, seller3, seller4] = accounts;
    let tokenInstance = await TestToken.new();
    let lientokenInstance = await TestToken.new();
    let factoryInstance = await Factory.new(lientokenInstance.address);
    let receipt = await factoryInstance.launchExchange(tokenInstance.address, { from: accounts[0] });
    let tokenAddress = receipt.logs[0].args.token;
    let exchangeInstance = await BoxExchange.at(receipt.logs[0].args.exchange);
    await tokenInstance.transfer(seller1, 2000000, { from: factory });
    await tokenInstance.transfer(seller2, 2000000, { from: factory });
    await tokenInstance.transfer(seller3, 2000000, { from: factory });
    await tokenInstance.transfer(seller4, 2000000, { from: factory });
    await tokenInstance.transfer(LP1, 3000000, { from: factory });
    await tokenInstance.transfer(LP2, 3000000, { from: factory });
    await tokenInstance.approve(exchangeInstance.address, 3000000, { from: LP1 });
    await tokenInstance.approve(exchangeInstance.address, 3000000, { from: LP2 });
    await tokenInstance.approve(exchangeInstance.address, 2000000, { from: seller1});
    await tokenInstance.approve(exchangeInstance.address, 2000000, { from: seller2});
    await tokenInstance.approve(exchangeInstance.address, 2000000, { from: seller3});
    await tokenInstance.approve(exchangeInstance.address, 2000000, { from: seller4});

    return {exchangeInstance, tokenInstance, lientokenInstance, factoryInstance};
  }

  module.exports = {
      setting: setting
  }