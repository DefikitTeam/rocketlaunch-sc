const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { saveContract, sleep } = require("./utils");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const network = hre.network.name;

  const ERC20Token = await hre.ethers.getContractFactory("ERC20Token");
  const tokenCustom = await ERC20Token.deploy( // get from Database to deploy
    "Victory_new",
    "VICTORNEW",
    8
  );

  await tokenCustom.deployed();

  console.log("token_custom address:", tokenCustom.address);
  await saveContract(network, "token_custom", tokenCustom.address);
  await sleep(5000);
  await hre.run("verify:verify", {
    address: tokenCustom.address,
    constructorArguments: [
     "Victory_new",
    "VICTORNEW",
      8
    ],
  });
  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
