const { getContractAddress } = require("ethers/lib/utils");
const { ethers } = require("hardhat");
const hre = require("hardhat");
require("@nomiclabs/hardhat-ethers");
const { saveContract, sleep } = require("./utils");

(async () => {
  try {
    const network = hre.network.name;
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const MultisendContractFactory = await ethers.getContractFactory("Multisend");
    const multisendAddress = await MultisendContractFactory.deploy();
    await saveContract(network, "multisend", multisendAddress.address);
    // await sleep(20000);
    // await hre.run("verify:verify", {
    //   address: multisendAddress.address,
    //   constructorArguments: []
    // });
    // console.log(multisendAddress.address);
  } catch (e) {
    console.log(e);
  }
})();


