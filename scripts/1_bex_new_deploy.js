const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const BexNew = await hre.ethers.getContractFactory("BexOperation");

  const bex_operation = await upgrades.deployProxy(BexNew, [
    contracts.dex_bex,
    contracts.weth,
    contracts.poolIdx_bex,
    contracts.rocket
  ]);

  await bex_operation.deployed();

  console.log("bex_operation address:", bex_operation.address);
  await saveContract(network, "bex_operation", bex_operation.address);
  console.log(`Deployed bex_operation to ${bex_operation.address}`);
  await sleep(10000);
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    bex_operation.address
  );
  console.log("Implementation contract address:", implementationAddress);
  await sleep(20000);
  await hre.run("verify:verify", {
    address: implementationAddress,
    constructorArguments: []
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
