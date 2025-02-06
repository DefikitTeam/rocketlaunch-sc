const { getContractAddress } = require("ethers/lib/utils");
const { ethers } = require("hardhat");
const hre = require("hardhat");
require("@nomiclabs/hardhat-ethers");
const { saveContract, sleep } = require("../utils");

(async () => {
  try {
    const network = hre.network.name;

    const Create3Factory = await ethers.getContractFactory("Create3Factory");
    const factory = await Create3Factory.deploy();
    await saveContract(network, "factoryCreate3", factory.address);

    const DeployRocketBera = await ethers.getContractFactory("DeployRocketBera");
    const deployer = await DeployRocketBera.deploy();
    await deployer.deployed();
    console.log("DeployRocketBera deployed to:", deployer.address);
    await saveContract(network, "deployCreate3", deployer.address);
   
  } catch (e) {
    console.log(e);
  }
})();


