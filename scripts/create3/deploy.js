const { ethers, upgrades } = require("hardhat");

const { saveContract, sleep, getContracts } = require("../utils");
async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

    // Deploy Create3Factory
    const Create3Factory = await ethers.getContractFactory("Create3Factory");
    const factory = await Create3Factory.attach(contracts.factoryCreate3);

    // Deploy RocketBera deployer
    const DeployRocketBera = await ethers.getContractFactory("DeployRocketBera");
    const deployer = await DeployRocketBera.attach(contracts.deployCreate3);
    await deployer.deployed();
    console.log("DeployRocketBera deployed to:", deployer.address);

    const salt = contracts.saltBytes;

    // Deploy RocketBera with predetermined address
    const tx = await deployer.deploy(
        factory.address,
        salt,
        contracts.platform,
        contracts.platformFee,
        contracts.feeAddr,
        contracts.fee,
        contracts.weth,
        contracts.bex_operation,
        contracts.blockInterval,
        contracts.minCap
    );
    await tx.wait();

    const deployedAddress = await deployer.computeAddress(factory.address, deployer.address, salt);
    console.log("RocketBera deployed to:", deployedAddress);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });