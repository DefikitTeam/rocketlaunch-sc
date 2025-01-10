const hre = require("hardhat");
const { ethers, upgrades } = hre;

const { saveContract, sleep } = require("./utils");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const network = hre.network.name;

    // const DeFiKitToken = await hre.ethers.getContractFactory("DeFiKitToken");
    // const tokenCustom = await DeFiKitToken.deploy( // get from Database to deploy
    //     "D. Mother Of Tokens @D_DMOT",
    //     "DMOT",
    //     18,
    //     "0x97Ca380672C5ea16997caA06c2De41C9BA9e3394",
    //     "9450000000000000000000000000000",
    //     deployer.address,
    //     "10500000000000000000000000000000",
    //     "0x41C3Ae3A4214c43852932D2dD2f48A8d5cABd427",
    //     "21000000000000000000000000000000",
    //     1711904400
    // );

    // await tokenCustom.deployed();

    // console.log("token_custom address:", tokenCustom.address);
    // await saveContract(network, "token_custom", tokenCustom.address);
    // await sleep(5000);
    await hre.run("verify:verify", {
        address: "0x1125eF7c7aBDB541c2CcB74c087c6456E0B02B29",
        constructorArguments: [
            "D. Mother Of Tokens @D_DMOT",
            "DMOT",
            18,
            "0x97Ca380672C5ea16997caA06c2De41C9BA9e3394",
            "9450000000000000000000000000000",
            deployer.address,
            "10500000000000000000000000000000",
            "0x41C3Ae3A4214c43852932D2dD2f48A8d5cABd427",
            "21000000000000000000000000000000",
            1711904400
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
