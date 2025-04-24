const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
    const network = hre.network.name;
    const [deployer] = await ethers.getSigners();
    const contracts = await getContracts(network)[network];

    const rocketFactory = await ethers.getContractFactory("Rocket");
    const rocketSC = await rocketFactory.attach(
        contracts.rocket
    );
    await rocketSC.setRocketTokenFactory( // set rocket token factory
        contracts.tokenFactory
    )
    console.log("done set rocket token factory");
    sleep(10000);
    const tokenFactory = await ethers.getContractFactory("RocketTokenFactory");
    const tokenFactorySC = await tokenFactory.attach(
        contracts.tokenFactory
    );
    await tokenFactorySC.setRocketLaunch( // set rocket launch
        contracts.rocket
    )
    console.log("done set rocket launch");
    console.log("done")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });