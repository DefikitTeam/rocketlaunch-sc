const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const BeraBearNFT = await hre.ethers.getContractFactory("BeraBearNFT");
  const nft = await upgrades.upgradeProxy(
    contracts.nft,
    BeraBearNFT
  );
  await rocket.deployed();
  await saveContract(network, "nft", nft.address);
  console.log(`Deployed NFT to ${nft.address}`);
  // Get the implementation contract address from the proxy
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    contracts.nft
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
