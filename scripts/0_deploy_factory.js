const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const network = hre.network.name;

  const PancakeFactory = await hre.ethers.getContractFactory("UniswapV2Factory");
  const factory = await PancakeFactory.deploy(
    deployer.address
  );

  await factory.deployed();

  console.log("factory address:", factory.address);
  await saveContract(network, "factory", factory.address);
  console.log(`Deployed factory to ${factory.address}`);
  await sleep(10000);
  await hre.run("verify:verify", {
    address: factory.address,
    constructorArguments: [deployer.address],
  });
  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
