const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { getContracts, saveContract, sleep } = require("./utils");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const PancakeRouter = await hre.ethers.getContractFactory("UniswapV2Router02");
  const router = await PancakeRouter.deploy(
    contracts.factory,
    contracts.weth
  );

  await router.deployed();

  console.log("router address:", router.address);
  await saveContract(network, "routerV2", router.address);
  console.log(`Deployed router to ${router.address}`);
  // await sleep(10000);
  // await hre.run("verify:verify", {
  //   address: router.address,
  //   constructorArguments: [contracts.factory, contracts.weth],
  // });
  // console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
