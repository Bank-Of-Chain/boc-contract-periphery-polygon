
const { default: BigNumber } = require('bignumber.js');
const { ethers } = require('hardhat');
const { assert, expect } = require('chai');

// const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
// const VaultFactory = hre.artifacts.require('VaultFactory.sol');
// const UniswapV3RiskOnVaultInitialize = hre.artifacts.require('UniswapV3RiskOnVaultInitialize.sol');


describe('VaultFactory', () => {
     /* create named accounts for contract roles */
 
     before(async () => {
         /* before tests */

     })
     
     beforeEach(async () => {
         /* before each context */
         // deploy vault impl
        this.UniswapV3RiskOnVaultInitialize = await ethers.getContractFactory("UniswapV3RiskOnVaultInitialize");
        this.uniswapV3RiskOnVaultInitialize = await this.UniswapV3RiskOnVaultInitialize.deploy();
        await this.uniswapV3RiskOnVaultInitialize.deployed()
        let vaultImpl = this.uniswapV3RiskOnVaultInitialize.address;

        // deploy VaultFactory
        this.VaultFactory = await ethers.getContractFactory("VaultFactory");
        this.vaultFactory = await this.VaultFactory.deploy(vaultImpl);
        await this.vaultFactory.deployed()

     })

     it("check constructor", async () =>{
        expect(await this.vaultFactory.vaultImplementation()).to.be.equal(this.uniswapV3RiskOnVaultInitialize.address);
     })
 
     it('createNewVault', async () => {
        let accounts = await ethers.getSigners();
        let creatorAddress = accounts[0];
        let firstUser = accounts[1];
        let secondUser = accounts[2];
        let externalAddress = accounts[3];
        let uniswapV3RiskOnHelper = accounts[4]

        this.ERC20 = await ethers.getContractFactory("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20");
        this.wantToken = await this.ERC20.deploy("test token", "TestT");
        await this.wantToken.deployed()

        expect(await this.vaultFactory.vaultAddressMap(firstUser.address,this.wantToken.address)).to.be.equal(ethers.constants.AddressZero);

        await this.vaultFactory.connect(firstUser).createNewVault(this.wantToken.address, uniswapV3RiskOnHelper.address);
        let vaultsLen = await this.vaultFactory.getVaultsLen()
        expect(vaultsLen).to.be.equal(1);
        let newVaultAddr = await await this.vaultFactory.vaultAddrList(vaultsLen - 1);
        let lastVaultAddr = await this.vaultFactory.vaultAddressMap(firstUser.address,this.wantToken.address);
        console.log("lastVaultAddr is",lastVaultAddr);
        expect(await this.vaultFactory.vaultAddressMap(firstUser.address,this.wantToken.address)).to.be.equal(newVaultAddr);

        await expect(this.vaultFactory.connect(firstUser).createNewVault(this.wantToken.address, uniswapV3RiskOnHelper.address)).to.revertedWith('Already created');

     });
    
 });
 