const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const CheckAddLiquidityV3 = await hre.ethers.getContractFactory("CheckAddLiquidityV3");
  const checkAddLiquidityV3 = await upgrades.upgradeProxy(
    contracts.checkAddLiquidityV3,
    CheckAddLiquidityV3
  );
  await checkAddLiquidityV3.deployed();
  await saveContract(network, "checkAddLiquidityV3", checkAddLiquidityV3.address);
  console.log(`Deployed CheckAddLiquidityV3 to ${checkAddLiquidityV3.address}`);
  // Get the implementation contract address from the proxy
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    contracts.checkAddLiquidityV3
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
