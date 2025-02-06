const hre = require("hardhat");

async function main() {
  const Lock = await hre.ethers.getContractFactory("Lock");
  const lock = await Lock.deploy(
  );
  await lock.deployed("1728383250");
  console.log("lock address:", lock.address);
  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
