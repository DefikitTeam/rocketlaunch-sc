const hre = require("hardhat");
const { ethers, upgrades } = hre;
const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const [deployer] = await ethers.getSigners();
  const contracts = await getContracts(network)[network];

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());
  const CheckAddLiquidityV3 = await hre.ethers.getContractFactory("CheckAddLiquidityV3");
  const checkAddLiquidityV3 = await upgrades.deployProxy(CheckAddLiquidityV3, [
    contracts.router,
    contracts.WETH
  ]);
  await checkAddLiquidityV3.deployed();
  await saveContract(network, "checkAddLiquidityV3", checkAddLiquidityV3.address);
  console.log("CheckAddLiquidityV3 deployed to:", checkAddLiquidityV3.address);
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    checkAddLiquidityV3.address
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
