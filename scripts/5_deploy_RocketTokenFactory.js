const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { saveContract, sleep, getContracts } = require("./utils");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const network = hre.network.name;
    const contracts = await getContracts(network)[network];

    const RocketTokenFactory = await hre.ethers.getContractFactory("RocketTokenFactory");
    const tokenFactory = await RocketTokenFactory.deploy();

    await tokenFactory.deployed();

    console.log("tokenFactory address:", tokenFactory.address);
    await saveContract(network, "tokenFactory", tokenFactory.address);
    await sleep(5000);
    await hre.run("verify:verify", {
        address: tokenFactory.address,
        constructorArguments: [],
    });
    console.log("Completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
