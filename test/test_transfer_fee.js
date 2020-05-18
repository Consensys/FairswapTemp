
const {
  BN,           // Big Number support
  expectEvent,  // Assertions for emitted events
  expectRevert,
  time // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');
let deploy = require('./deploy_contracts.js');

contract('BoxExchange', function(accounts) {
  describe('Transfer Fee', function() {
      let tokenInstance;
      let exchangeInstance;
      let lientokenInstance;
      const [factory, buyer1, buyer2, seller1, seller2, LP1, LP2, buyer3, seller3, seller4] = accounts;
  
    beforeEach(async () => {
        let instances = await deploy.setting(accounts);
        exchangeInstance = instances.exchangeInstance;
        tokenInstance = instances.tokenInstance;
        lientokenInstance = instances.lientokenInstance;
    });
    it("check fee for lien token", async () => {
      await exchangeInstance.initializeExchange(2000000, { from: LP1, value: 3000000});
        let process = [exchangeInstance.OrderEthToToken(16, false, {from: buyer1, value: 50000}),
          exchangeInstance.OrderEthToToken(16, false, { from: buyer2, value: 50000}),
          exchangeInstance.OrderTokenToEth(16, 20000, false, { from: seller1}),
          exchangeInstance.OrderTokenToEth(16, 20000, false, { from: seller2}),
                ];
        await Promise.all(process);
        await time.advanceBlock();
        await exchangeInstance.OrderTokenToEth(16, 300, true, { from: seller2});
        let tokensForLien = await exchangeInstance.getTokensForLien.call();
        assert.equal(tokensForLien[0], 59, "Invalid amount of BaseToken for Lien token")
        assert.equal(tokensForLien[1], 23, "Invalid amount of SettlementToken for Lien token")
      })

    it("transfer fee to lien correctly", async () => {
      await exchangeInstance.initializeExchange(2000000, {from: LP1, value: 3000000});
      let process = [exchangeInstance.OrderEthToToken(16, false, {from: buyer1, value: 50000}),
        exchangeInstance.OrderEthToToken(16, false, { from: buyer2, value: 50000}),
        exchangeInstance.OrderTokenToEth(16, 20000, false, { from: seller1}),
        exchangeInstance.OrderTokenToEth(16, 20000, false, { from: seller2}),
              ];
      await Promise.all(process);
      await time.advanceBlock();
      await time.advanceBlock();
      await exchangeInstance.OrderTokenToEth(16, 300, true, { from: seller2});
      await exchangeInstance.sendFeeToLien({from: factory});
      let ethBalance = await web3.eth.getBalance(lientokenInstance.address);
      assert.equal(ethBalance, 59, "Invalid eth amount lientoken will receive")
      let balance = await tokenInstance.balanceOf.call(lientokenInstance.address);
      assert.equal(balance, 23, "Invalid basetoken amount lientoken will receive");

    })
      
})
})