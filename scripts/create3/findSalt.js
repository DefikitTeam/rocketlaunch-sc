const hre = require("hardhat");
const { ethers, upgrades } = hre;
const { getContracts, saveContract, sleep } = require("../utils");

async function findSaltForAddress(targetSuffix, start = 1000000, range = 100000) {
    const RocketBera = await ethers.getContractFactory("RocketBera");
    const bytecodeOfCreateFactory = RocketBera.bytecode;
    let salt = start ;
    let maxIterations = start + range;
    const [signer] = await ethers.getSigners();
    
    while (salt < maxIterations) {
        const saltBytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(salt), 32);
        const address = ethers.utils.getCreate2Address(signer.address, saltBytes, ethers.utils.keccak256(bytecodeOfCreateFactory))
        console.log("address", address, "- salt", salt, "- saltBytes", saltBytes);
        if (address.toLowerCase().endsWith(targetSuffix.toLowerCase())) {
            console.log(`Found salt: ${salt}`);
            console.log(`Predicted address: ${address}`);
            return saltBytes;
        }
        
        salt++;
        if (salt % 1000 === 0) {
            console.log(`Tried ${salt} combinations...`);
        }

    }
    throw new Error(`Could not find matching address after ${maxIterations} attempts`);
}

async function main() {
    const network = hre.network.name;
    console.log("network", network);
    const salt = await findSaltForAddress( "aa", 0, 1000000,);
    console.log(`Salt in bytes32: ${salt}`);
    await saveContract(network, "salt", salt);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
