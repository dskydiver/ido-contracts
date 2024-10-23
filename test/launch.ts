import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs"
import { expect } from "chai"
import hre from "hardhat"

describe("LaunchFactory", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployLaunchFactoryFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners()

    const StableTokenFactory = await hre.ethers.getContractFactory('StableToken')
    const stableToken = await StableTokenFactory.deploy()
    await stableToken.waitForDeployment()
    const TokenFactory = await hre.ethers.getContractFactory("Token")
    const tokenSingleton = await TokenFactory.deploy("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")
    await tokenSingleton.waitForDeployment()
    const LaunchFactory = await hre.ethers.getContractFactory("Launch")
    const launchSingletone = await LaunchFactory.deploy(owner.address, await tokenSingleton.getAddress())
    await launchSingletone.waitForDeployment()
    const LaunchFactoryFactory = await hre.ethers.getContractFactory("LaunchFactory")
    const launchFactory = await LaunchFactoryFactory.deploy(owner.address, await launchSingletone.getAddress())
    await launchFactory.waitForDeployment()

    return { launchFactory, stableToken, owner, otherAccount }
  }

  describe("Deployment", function () {
    it("Should deploy launchfactory", async function () {
      const { launchFactory } = await loadFixture(deployLaunchFactoryFixture)

      console.log("LaunchFactory deployed to:", await launchFactory.getAddress())
    })

    it("Should deploy token", async function () {
      const { launchFactory, stableToken, owner, otherAccount } = await loadFixture(deployLaunchFactoryFixture)

      await (await launchFactory.connect(otherAccount).createLaunch({
        name: "IDO Token",
        symbol: "IDOT",
        price: 100,
        softCap: "700000000000000000000000000000000000",
        hardCap: "800000000000000000000000000000000000",
        purchaseLimitPerWallet: "100000000000000000000000000000000000",
        stableToken: await stableToken.getAddress()
      })).wait()

      const launchs = await launchFactory.getLaunches(otherAccount.address)
      console.log("launchs", launchs)

      expect(launchs.length).to.equal(1)
      const launch = await hre.ethers.getContractAt("Launch", launchs[0])

      const tokenAddress = await launch.token()
      const token = await hre.ethers.getContractAt("Token", tokenAddress)

      expect(await token.name()).to.equal("IDO Token")
      expect(await token.symbol()).to.equal("IDOT")
    })
  })
})
