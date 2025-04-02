const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { saveContract, sleep, getContracts } = require("./utils");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const network = hre.network.name;
    const contracts = await getContracts(network)[network];
    console.log(contracts);

    const TokenFactory = await hre.ethers.getContractFactory("TokenFactory");
    const tokenFactoryCommon = await TokenFactory.deploy();

    await tokenFactoryCommon.deployed();

    console.log("tokenFactoryCommon address:", tokenFactoryCommon.address);
    await saveContract(network, "tokenFactoryCommon", tokenFactoryCommon.address);
    // await sleep(5000);
    // await hre.run("verify:verify", {
    //     address: tokenFactoryCommon.address,
    //     constructorArguments: [],
    // });
    console.log("Completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
