const hre = require("hardhat");
const { ethers, upgrades } = hre;
const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const [deployer] = await ethers.getSigners();
  const contracts = await getContracts(network)[network];

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());
  const BeraBearNFT = await hre.ethers.getContractFactory("BeraBearNFT");
  const nft = await upgrades.deployProxy(BeraBearNFT, [
    contracts.apiUrl,
    contracts.minter_nft
  ]);
  await nft.deployed();
  await saveContract(network, "nft", nft.address);
  console.log("NFT deployed to:", nft.address);
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    nft.address
  );
  console.log("Implementation contract address:", implementationAddress);
  await sleep(20000);
  await hre.run("verify:verify", {
    address: implementationAddress,
    constructorArguments: []
  });

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
