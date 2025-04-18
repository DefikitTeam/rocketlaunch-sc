const hre = require("hardhat");
const { ethers, upgrades } = hre;
const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const [deployer] = await ethers.getSigners();
  const contracts = await getContracts(network)[network];

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());
  const TrustPoint = await hre.ethers.getContractFactory("CollectionTrustPoint");
  const trustpoint = await upgrades.deployProxy(TrustPoint, [
   contracts.apiUrl,
   contracts.minter_nft,
   contracts.rocket,
   contracts.initialPoints
  ]);
  await trustpoint.deployed();
  await saveContract(network, "trustpoint", trustpoint.address);
  console.log("Trustpoint deployed to:", trustpoint.address);
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    trustpoint.address
  );
  console.log("Implementation contract address:", implementationAddress);
  await sleep(10000);
  await hre.run("verify:verify", {
    address: implementationAddress,
    constructorArguments: [],
    contract: "contracts/CollectionTrustPoint.sol:CollectionTrustPoint"
  });

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
