const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const CheckWBERA = await hre.ethers.getContractFactory("CheckWBERA");
  const checkWbera = await CheckWBERA.deploy();

  await checkWbera.deployed();

  console.log("checkWbera address:", checkWbera.address);
  await saveContract(network, "checkWbera", checkWbera.address);
  console.log(`Deployed checkWbera to ${checkWbera.address}`);
  await sleep(10000);
  await hre.run("verify:verify", {
    address: checkWbera.address,
    constructorArguments: [],
  });
  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
