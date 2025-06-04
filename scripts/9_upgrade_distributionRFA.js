const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const DistributionRFA = await hre.ethers.getContractFactory("DistributionRFA");
  const distributionRFA = await upgrades.upgradeProxy(
    contracts.distributionRFA,
    DistributionRFA
  );
  await distributionRFA.deployed();
  await saveContract(network, "distributionRFA", distributionRFA.address);
  console.log(`Deployed DistributionRFA to ${distributionRFA.address}`);
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
    contract: "contracts/DistributionRFA.sol:DistributionRFA"
  });
  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
