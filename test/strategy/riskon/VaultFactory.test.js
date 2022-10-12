
const { default: BigNumber } = require('bignumber.js');
const { ethers } = require('hardhat');
const { assert, expect } = require('chai');

const WETH_ADDRESS = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619';
const USDC_ADDRESS = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';

const wethVaultIndex = 0;
const usdcVaultIndex = 1;

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

     })
     
     beforeEach(async () => {
         /* before each context */
         // deploy vault impl
        this.UniswapV3RiskOnVaultInitialize = await ethers.getContractFactory("UniswapV3RiskOnVaultInitialize");

        this.uniswapV3RiskOnVaultInitialize100 = await this.UniswapV3RiskOnVaultInitialize.deploy();
        await this.uniswapV3RiskOnVaultInitialize100.deployed()

        this.uniswapV3RiskOnVaultInitialize500 = await this.UniswapV3RiskOnVaultInitialize.deploy();
        await this.uniswapV3RiskOnVaultInitialize500.deployed()

        this.uniswapV3RiskOnVaultInitialize3000 = await this.UniswapV3RiskOnVaultInitialize.deploy();
        await this.uniswapV3RiskOnVaultInitialize3000.deployed()

        this.invalidVaultImpl = await this.UniswapV3RiskOnVaultInitialize.deploy();
        await this.invalidVaultImpl.deployed()

        this.newVaultImpl2Add = await this.UniswapV3RiskOnVaultInitialize.deploy();
        await this.newVaultImpl2Add.deployed()

        this.vaultImpllist = [
         this.uniswapV3RiskOnVaultInitialize100.address,
         this.uniswapV3RiskOnVaultInitialize500.address,
         this.uniswapV3RiskOnVaultInitialize3000.address
        ];

        // deploy AccessControlProxy
        this.AccessControlProxy = await ethers.getContractFactory("AccessControlProxy");
        this.accessControlProxy = await this.AccessControlProxy.deploy();
        await this.accessControlProxy.deployed()
        await this.accessControlProxy.initialize(this.deployer.address,this.deployer.address,this.deployer.address,this.deployer.address);
        
        // deploy VaultFactory
        this.VaultFactory = await ethers.getContractFactory("VaultFactory");
        this.vaultFactory = await this.VaultFactory.deploy(this.vaultImpllist,this.accessControlProxy.address);
        await this.vaultFactory.deployed()

        this.ERC20 = await ethers.getContractFactory("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20");
        this.nonWethOrUsdcToken = await this.ERC20.deploy("test token", "TestT");
        await this.nonWethOrUsdcToken.deployed()

     })

     it("check constructor", async () =>{
       let getVaultImplList = await this.vaultFactory.getVaultImplList();
       console.log("getVaultImplList is",getVaultImplList);
       for(let i = 0; i< this.vaultImpllist.length; i++) {
         expect(await this.vaultFactory.vaultImplList(i)).to.be.equal(this.vaultImpllist[i]);
         expect(await this.vaultFactory.vaultImpl2Index(this.vaultImpllist[i])).to.be.equal(i+1);
       }
       
     })

     it('createNewVault should revert if the wantToken is not WETH or USDC', async () => {
      let vaultImpl = this.vaultImpllist[0];
      await expect(this.vaultFactory.connect(this.firstUser)
      .createNewVault(
         this.nonWethOrUsdcToken.address,
         this.uniswapV3RiskOnHelper.address,
         vaultImpl
         )).to.revertedWith('The wantToken is not WETH or USDC');
     })

     it('createNewVault should revert if Vault Impl is invalid', async () => {
      await expect(this.vaultFactory.connect(this.firstUser)
      .createNewVault(
         WETH_ADDRESS, 
         this.uniswapV3RiskOnHelper.address,
         this.invalidVaultImpl.address
         )).to.revertedWith('Vault Impl is invalid');
     })
 
     it('createNewVault', async () => {

        //expect(await this.vaultFactory.vaultAddressMap(this.firstUser.address,this.nonWethOrUsdcToken.address)).to.be.equal(ethers.constants.AddressZero);
        let vaultImpl = this.vaultImpllist[0];
        //create new weth-vault
        await this.vaultFactory.connect(this.firstUser)
        .createNewVault(WETH_ADDRESS, this.uniswapV3RiskOnHelper.address,vaultImpl);

        let vaultsLen = await this.vaultFactory.getVaultsLen()
        expect(vaultsLen).to.be.equal(1);
        let newVaultAddr = await await this.vaultFactory.totalVaultAddrList(vaultsLen - 1);
        let userVaultAddr = await this.vaultFactory.vaultAddressMap(this.firstUser.address,vaultImpl,wethVaultIndex);
        console.log("userVaultAddr is",userVaultAddr);
        expect(await this.vaultFactory.vaultAddressMap(this.firstUser.address,vaultImpl,wethVaultIndex)).to.be.equal(newVaultAddr);

         //revert if weth-vault already created
        await expect(this.vaultFactory.connect(this.firstUser)
        .createNewVault(WETH_ADDRESS, this.uniswapV3RiskOnHelper.address,vaultImpl))
        .to.revertedWith('Already created');

       //create new usdc-vault
        vaultImpl = this.vaultImpllist[0];
        await this.vaultFactory.connect(this.firstUser)
        .createNewVault(USDC_ADDRESS, this.uniswapV3RiskOnHelper.address,vaultImpl);

        vaultsLen = await this.vaultFactory.getVaultsLen()
        expect(vaultsLen).to.be.equal(2);
        newVaultAddr = await await this.vaultFactory.totalVaultAddrList(vaultsLen - 1);
        
        userVaultAddr = await this.vaultFactory.vaultAddressMap(this.firstUser.address,vaultImpl,usdcVaultIndex);
        console.log("userVaultAddr is",userVaultAddr);
        expect(await this.vaultFactory.vaultAddressMap(this.firstUser.address,vaultImpl,usdcVaultIndex)).to.be.equal(newVaultAddr);

        //revert if weth-vault already created
        await expect(this.vaultFactory.connect(this.firstUser)
        .createNewVault(USDC_ADDRESS, this.uniswapV3RiskOnHelper.address,vaultImpl))
        .to.revertedWith('Already created');

     });

     //addVaultImpl
     it("addVaultImpl normal", async () =>{
      await this.vaultFactory.addVaultImpl(this.newVaultImpl2Add.address);
      let getVaultImplList = await this.vaultFactory.getVaultImplList();
      console.log("getVaultImplList is",getVaultImplList);
      expect(this.newVaultImpl2Add.address).to.be.equal(getVaultImplList[getVaultImplList.length-1]);
         
     })

     //addVaultImpl
     it("addVaultImpl revert if vault Impl existed", async () =>{
       await expect(this.vaultFactory.addVaultImpl(this.vaultImpllist[0]))
        .to.revertedWith('Vault Impl existed');
         
     })
    
 });
 