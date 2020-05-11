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
  describe('Add Order', function() {
    let tokenInstance;
    let exchangeInstance;
    const [factory, buyer1, buyer2, seller1, seller2, LP1, LP2, buyer3, seller3, seller4] = accounts;

    beforeEach(async () => {
      let instances = await deploy.setting(accounts);
      exchangeInstance = instances.exchangeInstance;
      tokenInstance = instances.tokenInstance;
    });
    
    it("should initialize correctly", async () => {
      await tokenInstance.approve(exchangeInstance.address, 20000, { from: LP1 });
      await exchangeInstance.initializeExchange(20000, { from: LP1, value: web3.utils.toWei("1", 'ether')});
      let pool = await exchangeInstance.getPoolAmount.call();
      assert.equal(pool[0].valueOf(), web3.utils.toWei("1", 'ether'), "Eth Pool should be 1 ETH");
      assert.equal(pool[1].valueOf(), 20000,  "Token Pool should be 20000");
      let totalShare = await exchangeInstance.getTotalShare.call();
      assert.equal(totalShare.valueOf(), 1000 * DECIMAL, "TotalShares should be 1000");
    });

    it("should add orders", async () => {
      await exchangeInstance.initializeExchange(40000, { from: LP1, value: web3.utils.toWei("2", 'ether')});
      const eth = web3.utils.toWei("1", 'ether');
      const ethSubFee = 997000000000000000;
      const tokenSubFee = 19940;
      const tokenSubFee2= 29940;
      await tokenInstance.approve(exchangeInstance.address, 20000, { from: LP2 });
      await tokenInstance.approve(exchangeInstance.address, 20000, { from: seller1 });
      await tokenInstance.approve(exchangeInstance.address, 20000, { from: seller2 });
      
      let process = [exchangeInstance.OrderEthToToken(1685175020, false, {from: buyer1, value: eth}),
          exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: eth}),
          exchangeInstance.OrderTokenToEth(1685175020, 20000, false, { from: seller1}),
          exchangeInstance.OrderTokenToEth(1685175020, 20000, true, { from: seller2}),
              ];     
      await Promise.all(process);
      let summary = await exchangeInstance.getBoxSummary.call();
      assert.equal(summary[0].valueOf(), eth, "Invalid buy order amount");
      assert.equal(summary[1].valueOf(), eth, "Invalid buy limit order amount");
      assert.equal(summary[2].valueOf(), 20000, "Invalid buy sell order amnount");
      assert.equal(summary[3].valueOf(), 20000, "Invalid sell limit order amount");

      let seller1Data = await exchangeInstance.getSellerdata.call(0, 0);
      assert.equal(seller1Data[0].valueOf(), seller1, "Orderer should be seller1 address");
      assert.equal(seller1Data[1].valueOf(), tokenSubFee,  "Seller1 order amount should be 19940");

      let seller2Data = await exchangeInstance.getSellerdata.call(0, 1);
      assert.equal(seller2Data[0].valueOf(), seller2, "Orderer should be seller2 address");
      assert.equal(seller2Data[1].valueOf(), tokenSubFee,  "Seller2 order amount should be 19940");

      let buyer1Data = await exchangeInstance.getBuyerdata.call(0, 0);
      assert.equal(buyer1Data[0].valueOf(), buyer1, "Orderer should be buyer1 address");
      assert.equal(buyer1Data[1].valueOf(), 997008973080757800,  "Buyer1 order amount should be 19940");


      let buyer2Data = await exchangeInstance.getBuyerdata.call(0, 1);
      assert.equal(buyer2Data[0].valueOf(), buyer2, "Orderer should be buyer2 address");
      assert.equal(buyer2Data[1].valueOf(), 997008973080757800, "Buyer2 order amount should be 19940");
      });
      
     
    it("should add and remove liquidity correctly", async () => {
      await exchangeInstance.initializeExchange(40000, { from: LP1, value: web3.utils.toWei("2", 'ether')});
      const eth = web3.utils.toWei("1", 'ether');
      await tokenInstance.approve(exchangeInstance.address, 20000, { from: LP2 });
      await exchangeInstance.removeLiquidity(1685175020, 1000, 2000,  500, { from: LP1})
      let LP1Data = await exchangeInstance.getShare.call(LP1);
      assert.equal(LP1Data.valueOf(), 500 * DECIMAL, "LP1 burns 500 shares");

      await exchangeInstance.addLiquidity(1685175020, 50, { from: LP2, value: eth});
      let LP2Data = await exchangeInstance.getShare.call(LP2);
      assert.equal(LP2Data.valueOf(), 500 * DECIMAL, "LP2 gets 100 shares");

      let totalshare = await exchangeInstance.getTotalShare.call();
      assert.equal(totalshare.valueOf(), 1000 * DECIMAL, "LP2 gets 100 shares");
    });

//buy
    it("price is inner tolerance rate", async () => {
      await exchangeInstance.initializeExchange(100000, { from: LP1, value: 200000});

      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 200}),
                exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 200}),
                exchangeInstance.OrderTokenToEth(1685175020, 150, false, { from: seller1}),
                exchangeInstance.OrderTokenToEth(1685175020, 150, true, { from: seller2}),
              ];
      await Promise.all(process);
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
      assert.equal(receipt.logs[0].args.Price, 500497512437810940, "Invalid price");
      assert.equal(receipt.logs[0].args.refundRateBuy0, 0, "Invalid refundRate of buy order");
      assert.equal(receipt.logs[0].args.refundRateBuy1, 0, "Invalid refundRate of buy limit order");
      assert.equal(receipt.logs[0].args.refundRateSell0, 0, "Invalid refundRate of sell order");
      assert.equal(receipt.logs[0].args.refundRateSell1, 0, "Invalid refundRate of sell limit order");
      assert.equal(receipt.logs[1].args.ethpool, 199802, "Invalid baseToken Pool");
      assert.equal(receipt.logs[1].args.tokenpool, 100100, "Invalid settlementToken Pool");
    });


    it("over tolerance rate, buy limit order is refunded partially", async () => {
      await exchangeInstance.initializeExchange(100000, { from: LP1, value: 200000});
    
      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 150}),
                exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 700}),
                exchangeInstance.OrderTokenToEth(1685175020, 150, false, { from: seller1}),
                exchangeInstance.OrderTokenToEth(1685175020, 100, true, { from: seller2}),
              ];
      await Promise.all(process);
      
      await time.advanceBlock();
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
      assert.equal(receipt.logs[0].args.Price, 499500000000000000, "Invalid price");
      assert.equal(receipt.logs[0].args.refundRateBuy0, 0, "Invalid refundRate of buy order");
      assert.equal(receipt.logs[0].args.refundRateBuy1, 213063992563992580, "Invalid refundRate of buy limit order");
      assert.equal(receipt.logs[0].args.refundRateSell0, 0, "Invalid refundRate of sell order");
      assert.equal(receipt.logs[0].args.refundRateSell1, 0, "Invalid refundRate of sell limit order");
      assert.equal(receipt.logs[1].args.ethpool, 200201, "Invalid baseToken Pool");
      assert.equal(receipt.logs[1].args.tokenpool, 99900, "Invalid settlementToken Pool");
    });

    it("over tolerance, sell limit order is refunded all", async () => {
      await exchangeInstance.initializeExchange(100000, { from: LP1, value: 200000});
    
      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 750}),
                exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 400}),
                exchangeInstance.OrderTokenToEth(1685175020, 100, false, { from: seller1}),
                exchangeInstance.OrderTokenToEth(1685175020, 150, true, { from: seller2}),
              ];

      await Promise.all(process);
      
      await time.advanceBlock();
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
      
      assert.equal(receipt.logs[0].args.Price, 499379190464365500, "Invalid price");
      assert.equal(receipt.logs[0].args.refundRateBuy0, 0, "Invalid refundRate of buy order");
      assert.equal(receipt.logs[0].args.refundRateBuy1,1003000000000000000, "Invalid refundRate of buy limit order");
      assert.equal(receipt.logs[0].args.refundRateSell0, 0, "Invalid refundRate of sell order");
      assert.equal(receipt.logs[0].args.refundRateSell1, 0, "Invalid refundRate of sell limit order");

      assert.equal(receipt.logs[1].args.ethpool,200250, "Invalid baseToken Pool");
      assert.equal(receipt.logs[1].args.tokenpool, 99876, "Invalid settlementToken Pool");
    })
      
      
    it("over tolerance, sell limit order is refunded partially", async () => {
      await exchangeInstance.initializeExchange(100000, { from: LP1, value: 200000});
    
      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 150}),
                exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 100}),
                exchangeInstance.OrderTokenToEth(1685175020, 100, false, { from: seller1}),
                exchangeInstance.OrderTokenToEth(1685175020, 150, true, { from: seller2}),
              ];

      await Promise.all(process);
      
      await time.advanceBlock();
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
      
      assert.equal(receipt.logs[0].args.Price, 500500000000000000, "Invalid price");
      assert.equal(receipt.logs[0].args.refundRateBuy0, 0, "Invalid refundRate of buy order");
      assert.equal(receipt.logs[0].args.refundRateBuy1, 0, "Invalid refundRate of buy limit order");
      assert.equal(receipt.logs[0].args.refundRateSell0, 0, "Invalid refundRate of sell order");
      assert.equal(receipt.logs[0].args.refundRateSell1, 164324833333333340, "Invalid refundRate of sell limit order");
      assert.equal(receipt.logs[1].args.ethpool, 199800, "Invalid baseToken Pool");
      assert.equal(receipt.logs[1].args.tokenpool, 100100,  "Invalid settlementToken Pool");
    })
    
    it("over tolerance, sell limit order is refunded totally", async () => {
      await exchangeInstance.initializeExchange(100000,{ from: LP1, value: 200000});
    
      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 150}),
                exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 100}),
                exchangeInstance.OrderTokenToEth(1685175020, 350, false, { from: seller1}),
                exchangeInstance.OrderTokenToEth(1685175020, 150, true, { from: seller2}),
              ];
      await Promise.all(process);
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
      
      assert.equal(receipt.logs[0].args.Price, 501120238984316654,"Invalid price");
      assert.equal(receipt.logs[0].args.refundRateBuy0, 0, "Invalid refundRate of buy order");
      assert.equal(receipt.logs[0].args.refundRateBuy1, 0, "Invalid refundRate of buy limit order");
      assert.equal(receipt.logs[0].args.refundRateSell0, 0, "Invalid refundRate of sell order");
      assert.equal(receipt.logs[0].args.refundRateSell1, 1003000000000000000, "Invalid refundRate of sell limit order");
      assert.equal(receipt.logs[1].args.ethpool, 199553, "Invalid baseToken Pool");
      assert.equal(receipt.logs[1].args.tokenpool, 100224,  "Invalid settlementToken Pool");
    })
      
    it("over secure rete, sell non-limit order refunded partially", async () => {
      await exchangeInstance.initializeExchange(10000, { from: LP1, value: 20000});

      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 150}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 100}),
        exchangeInstance.OrderTokenToEth(1685175020, 750, false, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 150, true, { from: seller2}),
      ];
      await Promise.all(process);
      
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
      
      assert.equal(receipt.logs[0].args.Price, 525000000000000000, "Invalid price");
      assert.equal(receipt.logs[0].args.refundRateBuy0, 0, "Invalid refundRate of buy order");
      assert.equal(receipt.logs[0].args.refundRateBuy1, 0, "Invalid refundRate of buy limit order");
      assert.equal(receipt.logs[0].args.refundRateSell0, 156802333333333340, "Invalid refundRate of sell order");
      assert.equal(receipt.logs[0].args.refundRateSell1, 1003000000000000000, "Invalid refundRate of sell limit order");
      assert.equal(receipt.logs[1].args.ethpool, 19048, "Invalid baseToken Pool");
      assert.equal(receipt.logs[1].args.tokenpool, 10501,  "Invalid settlementToken Pool");
    })
      
    
    it("over secure rete, buy non-limit order refunded partially", async () => {
      await exchangeInstance.initializeExchange(10000, { from: LP1, value: 20000});

      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 1800}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 400}),
        exchangeInstance.OrderTokenToEth(1685175020, 100, false, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 150, true, { from: seller2}),
      ];
      await Promise.all(process);
      
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
      
      assert.equal(receipt.logs[0].args.Price, 475000000000000000, "Invalid price");
      assert.equal(receipt.logs[0].args.refundRateBuy0, 121415789473684210, "Invalid refundRate of buy order");
      assert.equal(receipt.logs[0].args.refundRateBuy1, 1003000000000000000, "Invalid refundRate of buy limit order");
      assert.equal(receipt.logs[0].args.refundRateSell0, 0, "Invalid refundRate of sell order");
      assert.equal(receipt.logs[0].args.refundRateSell1, 0, "Invalid refundRate of sell limit order");
      assert.equal(receipt.logs[1].args.ethpool, 21056, "Invalid baseToken Pool");
      assert.equal(receipt.logs[1].args.tokenpool, 9500,  "Invalid settlementToken Pool");
      })
    
   
    it("buy limit order refunded totally2", async () => {
      await exchangeInstance.initializeExchange(10000, { from: LP1, value: 20000});

      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 1500}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 400}),
        exchangeInstance.OrderTokenToEth(1685175020, 100, false, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 150, true, { from: seller2}),
      ];
      await Promise.all(process);
      
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
      
      assert.equal(receipt.logs[0].args.Price, 476808905380333951 , "Invalid price");
      assert.equal(receipt.logs[0].args.refundRateBuy0, 0, "Invalid refundRate of buy order");
      assert.equal(receipt.logs[0].args.refundRateBuy1, 1003000000000000000, "Invalid refundRate of buy limit order");
      assert.equal(receipt.logs[0].args.refundRateSell0, 0, "Invalid refundRate of sell order");
      assert.equal(receipt.logs[0].args.refundRateSell1, 0, "Invalid refundRate of sell limit order");
      assert.equal(receipt.logs[1].args.ethpool, 20976, "Invalid baseToken Pool");
      assert.equal(receipt.logs[1].args.tokenpool, 9536,  "Invalid settlementToken Pool");
      })
    
    it("sell limit order refunded totally2", async () => {
      await exchangeInstance.initializeExchange(10000, { from: LP1, value: 20000});

      let process = [exchangeInstance.OrderEthToToken(1685175020, false, { from: buyer1, value: 150}),
        exchangeInstance.OrderEthToToken(1685175020, true, { from: buyer2, value: 100}),
        exchangeInstance.OrderTokenToEth(1685175020, 500, false, { from: seller1}),
        exchangeInstance.OrderTokenToEth(1685175020, 150, true, { from: seller2}),
      ];
      await Promise.all(process);
      
      await time.advanceBlock();
      let receipt = await exchangeInstance.OrderEthToToken(1685175020, 0, { from: buyer1, value: 10000});
    
      assert.equal(receipt.logs[0].args.Price, 518463810930576060, "Invalid price");
        assert.equal(receipt.logs[0].args.refundRateBuy0, 0, "Invalid refundRate of buy order");
        assert.equal(receipt.logs[0].args.refundRateBuy1, 0, "Invalid refundRate of buy limit order");
        assert.equal(receipt.logs[0].args.refundRateSell0, 0, "Invalid refundRate of sell order");
        assert.equal(receipt.logs[0].args.refundRateSell1, 1003000000000000000, "Invalid refundRate of sell limit order");
        assert.equal(receipt.logs[1].args.ethpool, 19288, "Invalid baseToken Pool");
        assert.equal(receipt.logs[1].args.tokenpool, 10370,  "Invalid settlementToken Pool");
      })
   
  });

})

