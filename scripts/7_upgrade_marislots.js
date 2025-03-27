const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const MariSlotsGame = await hre.ethers.getContractFactory("MariSlotsGame");
  const marislots = await upgrades.upgradeProxy(
    contracts.marislots,
    MariSlotsGame
  );
  await marislots.deployed();
  await saveContract(network, "marislots", marislots.address);
  console.log(`Deployed MariSlotsGame to ${marislots.address}`);
  // Get the implementation contract address from the proxy
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    marislots.address
  );
  console.log("Implementation contract address:", implementationAddress);
  await sleep(10000)
  await hre.run("verify:verify", {
    address: implementationAddress,
    constructorArguments: [
    ],
    contract: "contracts/MariSlotsGame.sol:MariSlotsGame"
  });
  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
