const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const BexNew = await hre.ethers.getContractFactory("BexOperation");
  const bex_operation = await upgrades.upgradeProxy(
    contracts.bex_operation,
    BexNew
  );
  await bex_operation.deployed();
  await saveContract(network, "bex_operation", bex_operation.address);
  console.log(`Deployed Rocket to ${bex_operation.address}`);
  // Get the implementation contract address from the proxy
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    contracts.bex_operation
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
