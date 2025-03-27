const hre = require("hardhat");
const { ethers, upgrades } = hre;
const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const [deployer] = await ethers.getSigners();
  const contracts = await getContracts(network)[network];

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());
  const MariSlotsGame = await hre.ethers.getContractFactory("MariSlotsGame");
  const marislots = await upgrades.deployProxy(MariSlotsGame, [
    contracts.routerV2,
    contracts.factory,
    contracts.weth,
    contracts.platform
  ]);
  await marislots.deployed();
  await saveContract(network, "marislots", marislots.address);
  console.log("marislots deployed to:", marislots.address);
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    marislots.address
  );
  console.log("Implementation contract address:", implementationAddress);
  await sleep(20000);
  await hre.run("verify:verify", {
    address: implementationAddress,
    constructorArguments: [],
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
