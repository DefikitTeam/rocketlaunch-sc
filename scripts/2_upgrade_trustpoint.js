const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const TrustPoint = await hre.ethers.getContractFactory("CollectionTrustPoint");
  const trustpoint = await upgrades.upgradeProxy(
    contracts.trustpoint,
    TrustPoint
  );
  await trustpoint.deployed();
  await saveContract(network, "trustpoint", trustpoint.address);
  console.log(`Deployed Trustpoint to ${trustpoint.address}`);
  // Get the implementation contract address from the proxy
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    contracts.trustpoint
  );
  console.log("Implementation contract address:", implementationAddress);
  await sleep(10000)
  await hre.run("verify:verify", {
    address: implementationAddress,
    constructorArguments: [
    ],
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
