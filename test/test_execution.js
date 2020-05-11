const BoxExchange = artifacts.require("BoxExchange");
const TestToken = artifacts.require("TestToken");
const Factory = artifacts.require("ExchangeFactory");
const {
  BN,           // Big Number support
  expectEvent,  // Assertions for emitted events
  expectRevert,
  time // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');
let deploy = require('./deploy_contracts.js');

contract('BoxExchange', function(accounts) {
  describe('Execution test', function() {
    let tokenInstance;
    let exchangeInstance;
    const [factory, buyer1, buyer2, seller1, seller2, LP1, LP2, buyer3, seller3, seller4] = accounts;

    beforeEach(async () => {
      let instances = await deploy.setting(accounts);
      exchangeInstance = instances.exchangeInstance;
      tokenInstance = instances.tokenInstance;
    });

  
    it("execute 16 orders in two transactions", async () => {
      await exchangeInstance.initializeExchange(1600000, { from: LP1, value: 2400000});
    
      let process = [
        exchangeInstance.OrderEthToToken(1685175020, false, { from: LP1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, { from: LP2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: LP1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: LP2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
        
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller2}), //execute till this order in the first execution
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller3}),
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller4}),  
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller2}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller3}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller4}),
              ];
      await Promise.all(process);
        
      await time.advanceBlock();
      await time.advanceBlock();
      
      let process2 = [exchangeInstance.OrderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer2, value: 1000})
      ]
      await Promise.all(process2);       
      
      balance = await tokenInstance.balanceOf.call(seller1);
      assert(balance > 1000, "balance of seller1 is invalid");
      balance = await tokenInstance.balanceOf.call(seller2);
      assert(balance > 1000, "balance of seller2 is invalid");  
  });   

  it("execute only two non-limit sell orders at first execution", async () => {
      await exchangeInstance.initializeExchange(1600000,{ from: LP1, value: 2400000});
    
      let process = [
        exchangeInstance.OrderEthToToken(1685175020, false, { from: LP1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, { from: LP2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: LP1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: LP2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
        
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller2}), //execute till this order in the first execution
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller3}),
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller4}),  
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller2}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller3}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller4}),
              ];
      await Promise.all(process);
      await time.advanceBlock();

      let receipt = await exchangeInstance.OrderTokenToEth(1685175020, 100, false, { from: seller2});
      assert.equal(receipt.logs[2].args.Price, 4, "`length` for buyorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy0,4, "`length` for buyorder Limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy1, 2, "`length` for sellorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell0, 0, "`length` for sellorder limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell1, 3, "unexecuted category is invalid"); 
    
      receipt = await exchangeInstance.OrderEthToToken(1685175020, false, {from: buyer1, value: 1000});
      assert.equal(receipt.logs[2].args.Price, 0, "`length` for buyorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy0, 0, "`length` for buyorder Limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy1, 2, "`length` for sellorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell0, 4, "`length` for sellorder limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell1, 0, "unexecuted category is invalid"); 
    }); 

    it("execution stops after executing all buyorder", async () => {
      await exchangeInstance.initializeExchange(1600000,{ from: LP1, value: 2400000});
    
      let process = [
        exchangeInstance.OrderEthToToken(1685175020, false, { from: LP1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, { from: LP2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer3, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: LP1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: LP2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer3, value: 1000}), //execute till this order in the first execution
        
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller2}),
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller3}),
        exchangeInstance.OrderTokenToEth(1685175020, 160, false, { from: seller4}),  
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller2}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller3}),
        exchangeInstance.OrderTokenToEth(1685175020, 1600, true, { from: seller4}),
              ];
      await Promise.all(process);
        
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, false, {from: buyer1, value: 1000});
      
      assert.equal(receipt.logs[2].args.Price, 5, "`length` for buyorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy0, 5, "`length` for buyorder Limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy1, 0, "`length` for sellorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell0, 0, "`length` for sellorder limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell1, 3, "unexecuted category is invalid"); 
      receipt = await exchangeInstance.excuteUnexecutedBox({from: buyer1});
      
      assert.equal(receipt.logs[2].args.Price, 0, "`length` for buyorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy0, 0, "`length` for buyorder Limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy1, 4, "`length` for sellorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell0, 4, "`length` for sellorder limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell1, 0, "unexecuted category is invalid");  
  });

  it("execute 22 orders in three transactions", async () => {
    await exchangeInstance.initializeExchange(1600000,{ from: LP1, value: 2400000});
  
    let process = [
      exchangeInstance.OrderEthToToken(1685175020, false, { from: LP1, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, false, { from: LP2, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer3, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, true, { from: LP1, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, true, { from: LP2, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
      exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer3, value: 1000}), //execute till this order in the first execution
      
      exchangeInstance.OrderTokenToEth(1685175020, 1600, false, { from: LP1}),
      exchangeInstance.OrderTokenToEth(1685175020, 1600, false, { from: LP2}), 
      exchangeInstance.OrderTokenToEth(1685175020, 1600, false, { from: seller1}), 
      exchangeInstance.OrderTokenToEth(1685175020, 1600, false, { from: seller2}),
      exchangeInstance.OrderTokenToEth(1685175020, 1600, false, { from: seller3}),
      exchangeInstance.OrderTokenToEth(1685175020, 1600, false, { from: seller4}), 
      exchangeInstance.OrderTokenToEth(1685175020, 160, true, { from: LP1}),
      exchangeInstance.OrderTokenToEth(1685175020, 160, true, { from: LP2}),
      exchangeInstance.OrderTokenToEth(1685175020, 160, true, { from: seller1}),
      exchangeInstance.OrderTokenToEth(1685175020, 160, true, { from: seller2}),//execute till this order in the second execution
      exchangeInstance.OrderTokenToEth(1685175020, 160, true, { from: seller3}),
      exchangeInstance.OrderTokenToEth(1685175020, 160, true, { from: seller4}),
            ];
    await Promise.all(process);
    await time.advanceBlock();
    await time.advanceBlock();
    let receipt = await exchangeInstance.OrderEthToToken(1685175020,false, {from: buyer1, value: 1000});
    
    assert.equal(receipt.logs[2].args.Price, 5, "`length` for buyorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy0, 5, "`length` for buyorder Limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy1, 0, "`length` for sellorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell0, 0, "`length` for sellorder limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell1, 3, "unexecuted category is invalid"); 

    receipt = await exchangeInstance.excuteUnexecutedBox({from: buyer1});
    
    assert.equal(receipt.logs[2].args.Price, 0, "`length` for buyorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy0, 0, "`length` for buyorder Limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy1, 6, "`length` for sellorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell0, 4, "`length` for sellorder limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell1, 4, "unexecuted category is invalid"); 
  
    receipt = await exchangeInstance.excuteUnexecutedBox({from: buyer1});
    
    assert.equal(receipt.logs[2].args.Price, 0, "`length` for buyorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy0, 0, "`length` for buyorder Limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy1, 0, "`length` for sellorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell0, 2, "`length` for sellorder limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell1, 0, "unexecuted category is invalid"); 
    
});
  
it("execute collectly after excuteUnexecutedBox()", async () => {
    const eth = web3.utils.toWei("1", 'ether');
    const eth1 = web3.utils.toWei("0.025", 'ether');
    const eth2 = web3.utils.toWei("0.1", 'ether');
    await exchangeInstance.initializeExchange(1000000,{ from: LP1, value: eth});
  
    let process = [
      exchangeInstance.OrderEthToToken(1685175020, false, {from: buyer1, value: eth1}),
      exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer2, value: eth1}),
      exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: eth2}),
      exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer1, value: eth2})];
    await Promise.all(process);
      
    await time.advanceBlock();
    let receipt = await exchangeInstance.excuteUnexecutedBox({from: factory});
    await time.advanceBlock();
    receipt = await exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer1, value: eth2});
    assert.equal(receipt.logs.length, 1, "execution should not be occured");
    assert.equal(receipt.logs[0].args.boxNumber, 3, "execution should not be occured");
  });  
  });
}); 