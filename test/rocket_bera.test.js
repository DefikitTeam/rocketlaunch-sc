const Web3 = require("web3");
const web3 = new Web3(
    new Web3.providers.HttpProvider("https://bartio.rpc.berachain.com")
);
const ABI = require("./ABI.json");
const ABI_TOKEN = require("../abi/ABI_TOKEN.json");

const pkey = ""; // Private Key 
const addressWallet = "0x1043987a09D87C13d42c7a62A0b0f4546e60Fc8F";
const ROCKET = "0x288020c23215a2472BcE3788764Cbc8E4E0aDbAE"
const BEX = "0x3eb0227CEc10245b29b9E5A6F0dA30221781Ae21"
const BEX_NEW = "0xe0928dAA95bD34E948e0d0E15Fa27C46E6888981"
const ADDRESS_TOKEN = '0x39dc7f297c921bcddea7ce4612a74db754dfd2c1'
const WETH = "0x7507c1dc16935B82698e4C63f2746A2fCf994dF8"

const activePool = async () => {
    const SC = new web3.eth.Contract(
        ABI,
        ROCKET
    );

    const params = {
        token: ADDRESS_TOKEN,
        fixedCapETH: "5000000000000000000",
        tokenForAirdrop: "10000000000000000000000",
        tokenForFarm: "40000000000000000000000",
        tokenForSale: "750000000000000000000000",
        tokenForAddLP: "200000000000000000000000",
        tokenPerPurchase: "100000000000000000000",
        maxRepeatPurchase: 100,
        startTime: 1714669800,
        endTime: 1715274600, // 1 week
        minDurationSell: 86400,
        maxDurationSell: 604800
    }
    const estGas = await SC.methods
        .activePool(
            params
        )
        .estimateGas({ from: addressWallet });



        
    console.log("estGas: ", estGas);
    web3.eth.accounts.wallet.add(pkey);
    const resultTransaction = await SC.methods.activePool(
        params
    ).send({
        from: addressWallet,
        gas: estGas
    });
    console.log("resultTransaction: ", resultTransaction);
};


const Buy = async () => {
    const SC = new web3.eth.Contract(
        ABI,
        ROCKET
    );
    const getAmountETH = '1000000000000000000'
    const estGas = await SC.methods
        .buy(
            ADDRESS_TOKEN,
            100,
            getAmountETH
        )
        .estimateGas({ from: addressWallet, value: getAmountETH });
    console.log("estGas: ", estGas);
    await SC.methods.buy(
        ADDRESS_TOKEN,
        100,
        getAmountETH
    ).send({
        from: addressWallet,
        gas: estGas,
        value: getAmountETH
    });
}

const finalize = async (pool) => {
    const SC = new web3.eth.Contract(
        ABI,
        ROCKET
    );
    const estGas = await SC.methods
        .finalize(
            pool
        )
        .estimateGas({ from: addressWallet });
    console.log("estGas: ", estGas);
    // web3.eth.accounts.wallet.add(pkey);
    // const resultTransaction = await SC.methods.finalize(
    //     pool
    // ).send({
    //     from: addressWallet,
    //     gas: 8000000
    // });
    // console.log("resultTransaction: ", resultTransaction);
}


function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

const loopBuy = async () => {
    for (let i = 0; i < 9; i++) {
        web3.eth.accounts.wallet.add(pkey);
        await Buy()
        await sleep(10000)
    }
}

// finalize("0x39dc7f297c921bcddea7ce4612a74db754dfd2c1")
