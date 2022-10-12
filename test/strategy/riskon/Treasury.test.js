
const { default: BigNumber } = require('bignumber.js');
const { ethers } = require('hardhat');
const { expect } = require('chai');
const { send, balance} = require("@openzeppelin/test-helpers");
const ether = require('@openzeppelin/test-helpers/src/ether');

const WETH_ADDRESS = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619';
const USDC_ADDRESS = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';

describe('VaultFactory', () => {

     before(async () => {
         /* before tests */
         /* create named this.accounts for contract roles */
         this.accounts = await ethers.getSigners();
         this.deployer = this.accounts[0];
         this.firstUser = this.accounts[1];
         this.secondUser = this.accounts[2];
         this.externalUser = this.accounts[3];
         this.uniswapV3RiskOnHelper = this.accounts[4];
         this.gov = this.accounts[5];
         this.delegate = this.accounts[6];
         this.vault = this.accounts[7];
         this.keeper = this.accounts[8];

     })
     
     beforeEach(async () => {
        // deploy AccessControlProxy
        this.AccessControlProxy = await ethers.getContractFactory("AccessControlProxy");
        this.accessControlProxy = await this.AccessControlProxy.deploy();
        await this.accessControlProxy.deployed()
        // 为什么第二个参数_delegate要和第一个参数_governance一样，不然报错deployer没有_delegate role
        await this.accessControlProxy.initialize(this.deployer.address,this.deployer.address,this.vault.address,this.keeper.address);

        this.ERC20Mint = await ethers.getContractFactory("ERC20Mint");
        this.wethMock = await this.ERC20Mint.deploy("weth mock token", "WETH");
        await this.wethMock.deployed()

        this.usdcMock = await this.ERC20Mint.deploy("usdc mock token", "USDC");
        await this.usdcMock.deployed()

        this.nonReceivableToken = await this.ERC20Mint.deploy("Non Receivable Token", "NRT");
        await this.nonReceivableToken.deployed()

        this.newReceivableToken = await this.ERC20Mint.deploy("New Receivable Token", "NEWRT");
        await this.newReceivableToken.deployed()

        // deploy Treasury
        this.Treasury = await ethers.getContractFactory("contracts/riskon/Treasury.sol:Treasury");
        this.treasury = await this.Treasury.deploy();
        await this.treasury.deployed();
        await this.treasury.initialize(this.accessControlProxy.address, this.wethMock.address, this.usdcMock.address);

     })

     it("check initialize", async () =>{
         expect(await this.treasury.isReceivableToken(this.wethMock.address)).to.be.equal(true);
         expect(await this.treasury.isReceivableToken(this.usdcMock.address)).to.be.equal(true);
       
     })

     it('receiveProfitFromVault revert if token is not receivable', async () => {
      let transferAmount = ethers.BigNumber.from(10).pow(18).mul(1000);
      await expect(this.treasury.receiveProfitFromVault(this.nonReceivableToken.address,transferAmount))
        .to.revertedWith('Not receivable token');
     })

     it('receiveProfitFromVault', async () => {
        let transferAmount = ethers.BigNumber.from(10).pow(18).mul(1000);
        // when takeProfitFlag is false, receive 0 from vault
        await this.treasury.receiveProfitFromVault(this.wethMock.address,transferAmount);

        // set takeProfitFlag is true
        await this.treasury.setTakeProfitFlag(true);
        expect(await this.treasury.takeProfitFlag()).to.be.equal(true);
        await this.wethMock.approve(this.treasury.address,transferAmount);
        await this.treasury.receiveProfitFromVault(this.wethMock.address,transferAmount);
        expect(await this.treasury.accVaultProfit(this.deployer.address,this.wethMock.address)).to.be.equal(transferAmount);

        expect(await this.treasury.balance(this.wethMock.address)).to.be.equal(transferAmount);
     })

     //setIsReceiveToken
     it('setTakeProfitFlag', async () => {
        expect(await this.treasury.takeProfitFlag()).to.be.equal(false);
        // set takeProfitFlag is true
        await this.treasury.setTakeProfitFlag(true);
        expect(await this.treasury.takeProfitFlag()).to.be.equal(true);
     })

     it('setIsReceivableToken', async () => {
        expect(await this.treasury.isReceivableToken(this.newReceivableToken.address)).to.be.equal(false);
        // add new receivable token 
        await this.treasury.setIsReceivableToken(this.newReceivableToken.address,true);
        expect(await this.treasury.isReceivableToken(this.newReceivableToken.address)).to.be.equal(true);
     })

     it('withdrawToken', async () => {
          let transferAmount = ethers.BigNumber.from(10).pow(18).mul(1000);
          // set takeProfitFlag is true
          await this.treasury.setTakeProfitFlag(true);
          await this.wethMock.approve(this.treasury.address,transferAmount);
          await this.treasury.receiveProfitFromVault(this.wethMock.address,transferAmount);
          
          await this.treasury.connect(this.keeper).withdrawToken(
            this.wethMock.address,
            this.keeper.address,
            ethers.BigNumber.from(transferAmount).div(2)
          );
          expect(await this.treasury.balance(this.wethMock.address)).to.be.equal(ethers.BigNumber.from(transferAmount).div(2));

          await this.wethMock.transfer(this.treasury.address,transferAmount);

          await this.treasury.connect(this.keeper).withdrawToken(
            this.wethMock.address,
            this.keeper.address,
            ethers.BigNumber.from(transferAmount).mul(3).div(2)
          );

          expect(await this.treasury.balance(this.wethMock.address)).to.be.equal(0);
      })

     it('withdrawETH', async () => {
          let transferAmount = ethers.BigNumber.from(10).pow(18).mul(100);

          await send.ether(this.deployer.address, this.treasury.address, transferAmount)

          await this.treasury.connect(this.keeper).withdrawETH(
            this.keeper.address,
            ethers.BigNumber.from(transferAmount).div(2)
          );

          let bal = await balance.current(this.treasury.address);

          expect(ethers.BigNumber.from(bal.toString()))
          .to.be.equal(ethers.BigNumber.from(transferAmount).div(2));

      })

 });
 