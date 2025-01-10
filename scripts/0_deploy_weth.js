const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract } = require("./utils");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const network = hre.network.name;

    const WETH = await hre.ethers.getContractFactory("WETH");
    const weth = await WETH.deploy();

    await weth.deployed();

    console.log("weth address:", weth.address);
    await saveContract(network, "weth", weth.address);
    console.log(`Deployed weth to ${weth.address}`);

    console.log("Completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
