const hre = require("hardhat");
const { ethers, upgrades } = hre;
const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const [deployer] = await ethers.getSigners();
  const contracts = await getContracts(network)[network];

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());
  const RocketIOTA = await hre.ethers.getContractFactory("RocketIOTA");
  const rocket = await upgrades.deployProxy(RocketIOTA, [
    contracts.platform,
    contracts.platformFee,
    contracts.feeAddr,
    contracts.fee,
    contracts.router,
    contracts.blockInterval,
    contracts.WETH
  ]);
  await rocket.deployed();
  await saveContract(network, "rocket", rocket.address);
  console.log("Rocket deployed to:", rocket.address);
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    rocket.address
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
