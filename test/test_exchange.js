const BoxExchange = artifacts.require("BoxExchange");
const TestToken = artifacts.require("TestToken");
const Factory = artifacts.require("ExchangeFactory");
const DECIMAL = 1000000000000000000;
const {
  BN,           // Big Number support
  expectEvent,  // Assertions for emitted events
  expectRevert,
  time // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');
let deploy = require('./deploy_contracts.js');


contract('BoxExchange', function(accounts) {
  describe('Add order', function() {
    let tokenInstance;
    let exchangeInstance;
    let factoryInstance;
    let lientokenInstance;
    const [factory, buyer1, buyer2, seller1, seller2, LP1, LP2, buyer3, seller3, seller4] = accounts;

    beforeEach(async () => {
      let instances = await deploy.setting(accounts);
      exchangeInstance = instances.exchangeInstance;
      tokenInstance = instances.tokenInstance;
      factoryInstance = instances.factoryInstance;
      lientokenInstance = instances.lientokenInstance;
    });
/*
    it("should deploy correctly", async () => {
      let lienAddress = await exchangeInstance.lienTokenAddress.call();
      assert.equal(lienAddress, lientokenInstance.address, "Address of Lien token is invalid");
      let tokenAddress = await exchangeInstance.tokenAddress.call();
      assert.equal(tokenAddress, tokenInstance.address, "Address of iDOL is invalid");
      let exchangeAddress = await factoryInstance.tokenToExchangeLookup.call(tokenInstance.address);
      assert.equal(exchangeAddress, exchangeInstance.address, "Address of Exchange is invalid");

    })
    
    it("should initialize correctly", async () => {
      await tokenInstance.approve(exchangeInstance.address, 20000, { from: LP1 });
      await exchangeInstance.initializeExchange(20000, { from: LP1, value: web3.utils.toWei("1", 'ether')});
      let ethpool = await exchangeInstance.ethPool.call();
      let tokenpool = await exchangeInstance.tokenPool.call();
      assert.equal(ethpool.valueOf(), web3.utils.toWei("1", 'ether'), "Eth Pool should be 1 ETH");
      assert.equal(tokenpool.valueOf(), 20000,  "Token Pool should be 20000");
      let totalShare = await exchangeInstance.totalSupply.call();
      assert.equal(totalShare.valueOf(), 1000 * DECIMAL, "TotalShares should be 1000");
    });
*/
      
     /*
    it("should add and remove liquidity correctly", async () => {
      await exchangeInstance.initializeExchange(40000, { from: LP1, value: web3.utils.toWei("2", 'ether')});
      const eth = web3.utils.toWei("1", 'ether');
      const shareBurned = web3.utils.toWei("500", 'ether');
      const minShares = web3.utils.toWei("50", 'ether');
      await tokenInstance.approve(exchangeInstance.address, 20000, { from: LP2 });
      await exchangeInstance.removeLiquidity(1685175020, 1000, 2000, shareBurned, { from: LP1})
      let LP1Data = await exchangeInstance.balanceOf.call(LP1);
      assert.equal(LP1Data.valueOf(), 500 * DECIMAL, "LP1 burns 500 shares");

      await exchangeInstance.addLiquidity(1685175020, minShares, { from: LP2, value: eth});
      let LP2Data = await exchangeInstance.balanceOf.call(LP2);
      assert.equal(LP2Data.valueOf(), 500 * DECIMAL, "LP2 gets 100 shares");

      let totalshare = await exchangeInstance.totalSupply.call();;
      assert.equal(totalshare.valueOf(), 1000 * DECIMAL, "LP2 gets 100 shares");
    });

     
    it("should revert invalid minshares", async () => {
      const minShares = web3.utils.toWei("500", 'ether');
      await exchangeInstance.initializeExchange(10000, { from: LP1, value: 20000});
      try {
        await exchangeInstance.addLiquidity(16, minShares, {from: LP2, value: 2000})
        } catch (err) {
          assert(err.toString().includes('revert'), err.toString());
        return;
      }
      assert(false, 'should revert');
    })

    it("should revert invalid min Base token", async () => {
      await exchangeInstance.initializeExchange(10000, { from: LP1, value: 20000});
      try {
        await exchangeInstance.removeLiquidity(16, 100000, 1500, 500, { from: LP1})
        } catch (err) {
          assert(err.toString().includes('revert'), err.toString());
        return;
      }
      assert(false, 'should revert');
    })

    it("should revert invalid min Settlement token", async () => {
      await exchangeInstance.initializeExchange(10000, { from: LP1, value: 20000});
      try {
        await exchangeInstance.removeLiquidity(16, 1000, 150000, 500, { from: LP1})
        } catch (err) {
          assert(err.toString().includes('revert'), err.toString());
        return;
      }
      assert(false, 'should revert');
    })

    it("should revert invalid share", async () => {
      const sharesBurned = web3.utils.toWei("1100", 'ether');
      await exchangeInstance.initializeExchange(10000, { from: LP1, value: 20000});
      try {
        await exchangeInstance.removeLiquidity(16, 1000, 1500, sharesBurned, { from: LP1})
        } catch (err) {
          assert(err.toString().includes('revert'), err.toString());
        return;
      }
      assert(false, 'should revert');
    })
*/
  it("should add orders, buy no-limit order opens a new box", async () => {
    await exchangeInstance.initializeExchange(40000, { from: LP1, value: web3.utils.toWei("2", 'ether')});
    const eth = web3.utils.toWei("0.1", 'ether');
    const ethSubFee = 99700897308075780;
    const tokenSubFee = 19940;
    const tokenSubFee2= 29940;
    await exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: eth});
    let process = [
        exchangeInstance.orderEthToToken(1685175020, true, { from: buyer2, value: eth}),
        exchangeInstance.orderTokenToEth(1685175020, 20000, false, { from: seller1}),
        exchangeInstance.orderTokenToEth(1685175020, 20000, true, { from: seller2}),
            ];     
    await Promise.all(process);
    let summary = await exchangeInstance.getBoxSummary.call();
    assert.equal(summary[0].valueOf(), eth, "Invalid buy order amount");
    assert.equal(summary[1].valueOf(), eth, "Invalid buy limit order amount");
    assert.equal(summary[2].valueOf(), 20000, "Invalid sell order amnount");
    assert.equal(summary[3].valueOf(), 20000, "Invalid sell limit order amount");

    let seller1Data = await exchangeInstance.getSellerdata.call(0, 0);
    assert.equal(seller1Data[0].valueOf(), seller1, "orderer should be seller1 address");
    assert.equal(seller1Data[1].valueOf(), tokenSubFee,  "Seller1 order amount should be 19940");

    let seller2Data = await exchangeInstance.getSellerdata.call(0, 1);
    assert.equal(seller2Data[0].valueOf(), seller2, "orderer should be seller2 address");
    assert.equal(seller2Data[1].valueOf(), tokenSubFee,  "Seller2 order amount should be 19940");

    let buyer1Data = await exchangeInstance.getBuyerdata.call(0, 0);
    assert.equal(buyer1Data[0].valueOf(), buyer1, "orderer should be buyer1 address");
    assert.equal(buyer1Data[1].valueOf(), 99700897308075780,  "Buyer1 order amount should be 19940");


    let buyer2Data = await exchangeInstance.getBuyerdata.call(0, 1);
    assert.equal(buyer2Data[0].valueOf(), buyer2, "orderer should be buyer2 address");
    assert.equal(buyer2Data[1].valueOf(), 99700897308075780, "Buyer2 order amount should be 19940");
  });
  it("should add orders, buy limit order opens a new box", async () => {
    await exchangeInstance.initializeExchange(40000, { from: LP1, value: web3.utils.toWei("2", 'ether')});
    const eth = web3.utils.toWei("0.1", 'ether');
    const ethSubFee = 997008973080757800;
    const tokenSubFee = 19940;
    const tokenSubFee2= 29940;
    await exchangeInstance.orderEthToToken(1685175020, true, { from: buyer2, value: eth});
    let process = [exchangeInstance.orderEthToToken(1685175020, false, {from: buyer1, value: eth}),
        exchangeInstance.orderTokenToEth(1685175020, 20000, false, { from: seller1}),
        exchangeInstance.orderTokenToEth(1685175020, 20000, true, { from: seller2}),
            ];     
    await Promise.all(process);
    let summary = await exchangeInstance.getBoxSummary.call();
    assert.equal(summary[0].valueOf(), eth, "Invalid buy order amount");
    assert.equal(summary[1].valueOf(), eth, "Invalid buy limit order amount");
    assert.equal(summary[2].valueOf(), 20000, "Invalid sell order amnount");
    assert.equal(summary[3].valueOf(), 20000, "Invalid sell limit order amount");

    let seller1Data = await exchangeInstance.getSellerdata.call(0, 0);
    assert.equal(seller1Data[0].valueOf(), seller1, "orderer should be seller1 address");
    assert.equal(seller1Data[1].valueOf(), tokenSubFee,  "Seller1 order amount should be 19940");

    let seller2Data = await exchangeInstance.getSellerdata.call(0, 1);
    assert.equal(seller2Data[0].valueOf(), seller2, "orderer should be seller2 address");
    assert.equal(seller2Data[1].valueOf(), tokenSubFee,  "Seller2 order amount should be 19940");

    let buyer1Data = await exchangeInstance.getBuyerdata.call(0, 0);
    assert.equal(buyer1Data[0].valueOf(), buyer1, "orderer should be buyer1 address");
    assert.equal(buyer1Data[1].valueOf(), 99700897308075780,  "Buyer1 order amount should be 19940");


    let buyer2Data = await exchangeInstance.getBuyerdata.call(0, 1);
    assert.equal(buyer2Data[0].valueOf(), buyer2, "orderer should be buyer2 address");
    assert.equal(buyer2Data[1].valueOf(), 99700897308075780, "Buyer2 order amount should be 19940");
  });

  it("should add orders, sell no-limit order opens a new box", async () => {
      const tokenSubFee1 = 19940;
      const tokenSubFee2 = 29910;
      const tokenSubFee3 = 39880;
      const tokenSubFee4 = 49850;
      await exchangeInstance.initializeExchange(30000,{ from: LP1, value: 20000});
      await exchangeInstance.orderTokenToEth(16, 40000, false, { from: seller1});
      let process = [
                exchangeInstance.orderEthToToken(16, true, { from: buyer2, value: 30000}),
                exchangeInstance.orderTokenToEth(16, 50000, true, { from: seller2}),
                exchangeInstance.orderEthToToken(16, false, {from: buyer1, value: 20000}),
              ];
      await Promise.all(process);
      await time.advanceBlock();
    
      let summary = await exchangeInstance.getBoxSummary.call();
      assert.equal(summary[0].valueOf(), 20000, "Invalid buy order amount");
      assert.equal(summary[1].valueOf(), 30000, "Invalid buy limit order amount");
      assert.equal(summary[2].valueOf(), 40000, "Invalid sell order amount");
      assert.equal(summary[3].valueOf(), 50000, "Invalid sell limit order amount");

      let buyer1Data = await exchangeInstance.getBuyerdata.call(0, 0);
      assert.equal(buyer1Data[0].valueOf(), buyer1, "orderer should be buyer1 address");
      assert.equal(buyer1Data[1].valueOf(), tokenSubFee1, "Buyer1 order should be 19940");


      let buyer2Data = await exchangeInstance.getBuyerdata.call(0, 1);
      assert.equal(buyer2Data[0].valueOf(), buyer2, "orderer should be buyer2 address");
      assert.equal(buyer2Data[1].valueOf(), tokenSubFee2, "Buyer2 should be 29910"); 

      let seller1Data = await exchangeInstance.getSellerdata.call(0, 0);
      assert.equal(seller1Data[0].valueOf(), seller1, "orderer should be seller1 address");
      assert.equal(seller1Data[1].valueOf(), tokenSubFee3, "Seller1 order amount should be 39880");

      let seller2Data = await exchangeInstance.getSellerdata.call(0, 1);
      assert.equal(seller2Data[0].valueOf(), seller2, "orderer should be seller1 address");
      assert.equal(seller2Data[1].valueOf(), tokenSubFee4, "Seller2 order amount should be 49850 token");

    });
  
    it("should add orders, sell limit order opens a new box", async () => {
      const tokenSubFee1 = 19940;
      const tokenSubFee2 = 29910;
      const tokenSubFee3 = 39880;
      const tokenSubFee4 = 49850;
      await exchangeInstance.initializeExchange(30000,{ from: LP1, value: 20000});
      await exchangeInstance.orderTokenToEth(16, 50000, true, { from: seller2});
      let process = [
                exchangeInstance.orderEthToToken(16, true, { from: buyer2, value: 30000}),
                exchangeInstance.orderTokenToEth(16, 40000, false, { from: seller1}),
                exchangeInstance.orderEthToToken(16, false, {from: buyer1, value: 20000}),
              ];
      await Promise.all(process);
      await time.advanceBlock();
    
      let summary = await exchangeInstance.getBoxSummary.call();
      assert.equal(summary[0].valueOf(), 20000, "Invalid buy order amount");
      assert.equal(summary[1].valueOf(), 30000, "Invalid buy limit order amount");
      assert.equal(summary[2].valueOf(), 40000, "Invalid sell order amount");
      assert.equal(summary[3].valueOf(), 50000, "Invalid sell limit order amount");

      let buyer1Data = await exchangeInstance.getBuyerdata.call(0, 0);
      assert.equal(buyer1Data[0].valueOf(), buyer1, "orderer should be buyer1 address");
      assert.equal(buyer1Data[1].valueOf(), tokenSubFee1, "Buyer1 order should be 19940");


      let buyer2Data = await exchangeInstance.getBuyerdata.call(0, 1);
      assert.equal(buyer2Data[0].valueOf(), buyer2, "orderer should be buyer2 address");
      assert.equal(buyer2Data[1].valueOf(), tokenSubFee2, "Buyer2 should be 29910"); 

      let seller1Data = await exchangeInstance.getSellerdata.call(0, 0);
      assert.equal(seller1Data[0].valueOf(), seller1, "orderer should be seller1 address");
      assert.equal(seller1Data[1].valueOf(), tokenSubFee3, "Seller1 order amount should be 39880");

      let seller2Data = await exchangeInstance.getSellerdata.call(0, 1);
      assert.equal(seller2Data[0].valueOf(), seller2, "orderer should be seller1 address");
      assert.equal(seller2Data[1].valueOf(), tokenSubFee4, "Seller2 order amount should be 49850 token");

    });

    it("should add orders, orderer orders the same order in the same box", async () => {
      const tokenSubFee1 = 19940;
      const tokenSubFee2 = 29910;
      const tokenSubFee3 = 39880;
      const tokenSubFee4 = 49850;
      await exchangeInstance.initializeExchange(30000,{ from: LP1, value: 20000});
      let process = [exchangeInstance.orderTokenToEth(16, 20000, false, { from: seller1}),,
                exchangeInstance.orderEthToToken(16, false, {from: buyer1, value: 10000}),
                exchangeInstance.orderTokenToEth(16, 20000, false, { from: seller1}),
                exchangeInstance.orderEthToToken(16, false, {from: buyer1, value: 10000}),
              ];
      let message = await Promise.all(process);
      await time.advanceBlock();
    
      let summary = await exchangeInstance.getBoxSummary.call();
      assert.equal(summary[0].valueOf(), 20000, "Invalid buy order amount");
      
      assert.equal(summary[2].valueOf(), 40000, "Invalid sell order amount");
  

      let buyer1Data = await exchangeInstance.getBuyerdata.call(0, 0);
      assert.equal(buyer1Data[0].valueOf(), buyer1, "orderer should be buyer1 address");
      assert.equal(buyer1Data[1].valueOf(), tokenSubFee1, "Buyer1 order should be 19940");

      let seller1Data = await exchangeInstance.getSellerdata.call(0, 0);
      assert.equal(seller1Data[0].valueOf(), seller1, "orderer should be seller1 address");
      assert.equal(seller1Data[1].valueOf(), tokenSubFee3, "Seller1 order amount should be 39880");
    });

  })
})