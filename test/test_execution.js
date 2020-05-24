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
    
    it("execute 16 orders in two transactions by buy order", async () => {
      await exchangeInstance.initializeExchange(1600000, { from: LP1, value: 2400000});
    
      let process = [
        exchangeInstance.orderEthToToken(1685175020, false, { from: LP1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, { from: LP2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: LP1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: LP2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
        
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller1}),
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller2}), //execute till this order in the first execution
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller3}),
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller4}),  
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller1}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller2}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller3}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller4}),
              ];
      await Promise.all(process);
        
      await time.advanceBlock();
      await time.advanceBlock();
      
      let process2 = [exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, { from: buyer2, value: 1000})
      ]
      await Promise.all(process2);       
      
      balance = await tokenInstance.balanceOf.call(seller1);
      assert(balance > 1000, "balance of seller1 is invalid");
      balance = await tokenInstance.balanceOf.call(seller2);
      assert(balance > 1000, "balance of seller2 is invalid");  
  });

  it("execute 16 orders in two transactions by sell order", async () => {
    await exchangeInstance.initializeExchange(1600000, { from: LP1, value: 2400000});
  
    let process = [
      exchangeInstance.orderEthToToken(1685175020, false, { from: LP1, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, false, { from: LP2, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: LP1, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: LP2, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
      
      exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller1}),
      exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller2}), //execute till this order in the first execution
      exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller3}),
      exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller4}),  
      exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller1}),
      exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller2}),
      exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller3}),
      exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller4}),
            ];
    await Promise.all(process);
      
    await time.advanceBlock();
    await time.advanceBlock();
    
    let process2 = [exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller1}),
      exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller2}),
    ]
    await Promise.all(process2);       
    
    balance = await tokenInstance.balanceOf.call(seller1);
    assert(balance > 1000, "balance of seller1 is invalid");
    balance = await tokenInstance.balanceOf.call(seller2);
    assert(balance > 1000, "balance of seller2 is invalid");  
});

it("execute 16 orders in two transactions by executeUnexecutedBox()", async () => {
  await exchangeInstance.initializeExchange(1600000, { from: LP1, value: 2400000});

  let process = [
    exchangeInstance.orderEthToToken(1685175020, false, { from: LP1, value: 1000}),
    exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
    exchangeInstance.orderEthToToken(1685175020, false, { from: LP2, value: 1000}),
    exchangeInstance.orderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
    exchangeInstance.orderEthToToken(1685175020, true, { from: LP1, value: 1000}),
    exchangeInstance.orderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
    exchangeInstance.orderEthToToken(1685175020, true, { from: LP2, value: 1000}),
    exchangeInstance.orderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
    
    exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller1}),
    exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller2}), //execute till this order in the first execution
    exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller3}),
    exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller4}),  
    exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller1}),
    exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller2}),
    exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller3}),
    exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller4}),
          ];
  await Promise.all(process);
    
  await time.advanceBlock();
  await time.advanceBlock();
  
  let process2 = [exchangeInstance.executeUnexecutedBox({from: buyer1}),
    exchangeInstance.executeUnexecutedBox({from: buyer1})
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
        exchangeInstance.orderEthToToken(1685175020, false, { from: LP1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, { from: LP2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: LP1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: LP2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
        
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller1}),
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller2}), //execute till this order in the first execution
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller3}),
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller4}),  
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller1}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller2}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller3}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller4}),
              ];
      await Promise.all(process);
      await time.advanceBlock();

      let receipt = await exchangeInstance.orderTokenToEth(1685175020, 100, false, { from: seller2});
      assert.equal(receipt.logs[2].args.Price, 4, "`length` for buyorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy0,4, "`length` for buyorder Limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy1, 2, "`length` for sellorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell0, 0, "`length` for sellorder limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell1, 3, "unexecuted category is invalid"); 
    
      receipt = await exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: 1000});
      assert.equal(receipt.logs[2].args.Price, 0, "`length` for buyorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy0, 0, "`length` for buyorder Limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy1, 2, "`length` for sellorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell0, 4, "`length` for sellorder limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell1, 0, "unexecuted category is invalid"); 
    }); 

    it("execution stops after executing all buyorder", async () => {
      await exchangeInstance.initializeExchange(1600000,{ from: LP1, value: 2400000});
    
      let process = [
        exchangeInstance.orderEthToToken(1685175020, false, { from: LP1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, { from: LP2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, false, { from: buyer3, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: LP1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: LP2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
        exchangeInstance.orderEthToToken(1685175020, true, { from: buyer3, value: 1000}), //execute till this order in the first execution
        
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller1}),
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller2}),
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller3}),
        exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller4}),  
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller1}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller2}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller3}),
        exchangeInstance.orderTokenToEth(1685175020, 1600, true, { from: seller4}),
              ];
      await Promise.all(process);
        
      await time.advanceBlock();
      let receipt = await exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: 1000});
      
      assert.equal(receipt.logs[2].args.Price, 5, "`length` for buyorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy0, 5, "`length` for buyorder Limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy1, 0, "`length` for sellorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell0, 0, "`length` for sellorder limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell1, 3, "unexecuted category is invalid"); 
      receipt = await exchangeInstance.executeUnexecutedBox({from: buyer1});
      
      assert.equal(receipt.logs[2].args.Price, 0, "`length` for buyorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy0, 0, "`length` for buyorder Limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateBuy1, 4, "`length` for sellorder is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell0, 4, "`length` for sellorder limit is invalid"); 
      assert.equal(receipt.logs[2].args.refundRateSell1, 0, "unexecuted category is invalid");  
  });

  it("execute 22 orders in three transactions", async () => {
    await exchangeInstance.initializeExchange(1600000,{ from: LP1, value: 2400000});
  
    let process = [
      exchangeInstance.orderEthToToken(1685175020, false, { from: LP1, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, false, { from: LP2, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, false, { from: buyer1, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, false, { from: buyer2, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, false, { from: buyer3, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: LP1, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: LP2, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: buyer1, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: buyer2, value: 1000}),
      exchangeInstance.orderEthToToken(1685175020, true, { from: buyer3, value: 1000}), //execute till this order in the first execution
      
      exchangeInstance.orderTokenToEth(1685175020, 1600, false, { from: LP1}),
      exchangeInstance.orderTokenToEth(1685175020, 1600, false, { from: LP2}), 
      exchangeInstance.orderTokenToEth(1685175020, 1600, false, { from: seller1}), 
      exchangeInstance.orderTokenToEth(1685175020, 1600, false, { from: seller2}),
      exchangeInstance.orderTokenToEth(1685175020, 1600, false, { from: seller3}),
      exchangeInstance.orderTokenToEth(1685175020, 1600, false, { from: seller4}), 
      exchangeInstance.orderTokenToEth(1685175020, 160, true, { from: LP1}),
      exchangeInstance.orderTokenToEth(1685175020, 160, true, { from: LP2}),
      exchangeInstance.orderTokenToEth(1685175020, 160, true, { from: seller1}),
      exchangeInstance.orderTokenToEth(1685175020, 160, true, { from: seller2}),//execute till this order in the second execution
      exchangeInstance.orderTokenToEth(1685175020, 160, true, { from: seller3}),
      exchangeInstance.orderTokenToEth(1685175020, 160, true, { from: seller4}),
            ];
    await Promise.all(process);
    await time.advanceBlock();
    await time.advanceBlock();
    let receipt = await exchangeInstance.orderEthToToken(1685175020,false, {from: buyer1, value: 1000});
    
    assert.equal(receipt.logs[2].args.Price, 5, "`length` for buyorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy0, 5, "`length` for buyorder Limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy1, 0, "`length` for sellorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell0, 0, "`length` for sellorder limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell1, 3, "unexecuted category is invalid"); 

    receipt = await exchangeInstance.executeUnexecutedBox({from: buyer1});
    
    assert.equal(receipt.logs[2].args.Price, 0, "`length` for buyorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy0, 0, "`length` for buyorder Limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy1, 6, "`length` for sellorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell0, 4, "`length` for sellorder limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell1, 4, "unexecuted category is invalid"); 
  
    receipt = await exchangeInstance.executeUnexecutedBox({from: buyer1});
    
    assert.equal(receipt.logs[2].args.Price, 0, "`length` for buyorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy0, 0, "`length` for buyorder Limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateBuy1, 0, "`length` for sellorder is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell0, 2, "`length` for sellorder limit is invalid"); 
    assert.equal(receipt.logs[2].args.refundRateSell1, 0, "unexecuted category is invalid"); 
    
});
  
it("execute collectly after executeUnexecutedBox()", async () => {
  const eth = web3.utils.toWei("0.1", 'ether');
  await exchangeInstance.initializeExchange(1000000,{ from: LP1, value: eth});
    
  await exchangeInstance.orderTokenToEth(1685175020, 160, false, { from: seller4});
    
  await time.advanceBlock();
  await time.advanceBlock();
  await exchangeInstance.executeUnexecutedBox({from: buyer1});
  let receipt = await exchangeInstance.orderEthToToken(1685175020, true, { from: buyer1, value: 10000});
  assert.equal(receipt.logs.length, 1, "execution should not be occured");
  assert.equal(receipt.logs[0].args.boxNumber, 3, "execution should not be occured");
  });  
  });
}); 