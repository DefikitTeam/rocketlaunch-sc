const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { saveContract, sleep, getContracts } = require("./utils");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const network = hre.network.name;
    const contracts = await getContracts(network)[network];

    const MotherOfToken = await hre.ethers.getContractFactory("RocketToken");
    const token_rocket = await MotherOfToken.deploy( // get from Database to deploy
        "Rocket Token",
        "ROCKET_ONE_HOURS",
        18,
        "1000000000000000000000000"
    );

    await token_rocket.deployed();

    console.log("token_rocket address:", token_rocket.address);
    await saveContract(network, "token_rocket", token_rocket.address);
    await sleep(5000);
    await hre.run("verify:verify", {
        address: token_rocket.address,
        constructorArguments: [
            "Rocket Token",
            "ROCKET_ONE_HOURS",
            18,
            "1000000000000000000000000"
        ],
    });
    console.log("Completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
