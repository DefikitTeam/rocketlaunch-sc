const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const Rocket = await hre.ethers.getContractFactory("RocketBera");
  const rocket = await upgrades.upgradeProxy(
    contracts.rocket,
    Rocket
  );
  await rocket.deployed();
  await saveContract(network, "rocket", rocket.address);
  console.log(`Deployed Rocket to ${rocket.address}`);
  // Get the implementation contract address from the proxy
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    contracts.rocket
  );
  console.log("Implementation contract address:", implementationAddress);
  await sleep(10000)
  await hre.run("verify:verify", {
    address: implementationAddress,
    constructorArguments: [
    ]
  });
  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
