const hre = require("hardhat");
const { ethers, upgrades } = hre;
const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
    const network = hre.network.name;
    const [deployer] = await ethers.getSigners();
    const contracts = await getContracts(network)[network];

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());
    const DistributionRFA = await hre.ethers.getContractFactory("DistributionRFA");
    const distributionRFA = await upgrades.deployProxy(DistributionRFA, [
        contracts.platform
    ]);
    await distributionRFA.deployed();
    await saveContract(network, "distributionRFA", distributionRFA.address);
    console.log("DistributionRFA deployed to:", distributionRFA.address);
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        distributionRFA.address
    );
    console.log("Implementation contract address:", implementationAddress);
    await sleep(20000);
    await hre.run("verify:verify", {
        address: implementationAddress,
        constructorArguments: []
    });

    console.log("Completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
