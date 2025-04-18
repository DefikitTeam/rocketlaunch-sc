require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
require("hardhat-abi-exporter");
require("hardhat-deploy");
require("hardhat-log-remover");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-contract-sizer");
require("hardhat-typechain");
require("hardhat-contract-sizer");

const dotenv = require("dotenv");
dotenv.config();

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const POLYGON_API_KEY = process.env.POLYGON_API_KEY;
const BSC_API_KEY = process.env.BSC_API_KEY;
const INFURA_API_KEY = process.env.INFURA_API_KEY;
const ALCHEMY_KEY = process.env.ALCHEMY_KEY;
const ARBITRUM_KEY = process.env.ARBITRUM_KEY;
const OPTIMISM_KEY = process.env.OPTIMISM_KEY;
const BLAST_KEY = process.env.BLAST_KEY;
const BASE_KEY = process.env.BASE_KEY;
const IOTA_KEY = process.env.IOTA_KEY;
const WORLDCHAIN_API_KEY = process.env.WORLDCHAIN_API_KEY;
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY;

module.exports = {
  abiExporter: {
    path: "./abi",
    clear: true,
    flat: true,
  },
  solidity: {
    compilers: [
      {
        version: "0.4.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },

      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 0,
          },
        },
      },
    ],
  },


  etherscan: {
    apiKey: {
    //   base_sepolia: BASE_KEY,
    bepolia: "62DU99P5D8J8DXBYY55GKPE2T83VD6N13E",
      // base: BASE_KEY,
      // iota: 'empty',
      // unichain_sepolia: 'empty'
      // worldchain_testnet: WORLDCHAIN_API_KEY
      // gravity_testnet: "abc",
    },
    customChains: [
      {
        // network: "base",
        // chainId: 8453,
        // urls: {
        //   apiURL: "https://api.basescan.org/api", // https://api.basescan.org/api
        //   browserURL: "https://basescan.org"
        // },

        // network: "base_sepolia",
        // chainId: 84532,
        // urls: {
        //   apiURL: "https://api-sepolia.basescan.org/api", // https://api.basescan.org/api
        //   browserURL: "https://sepolia.basescan.org"
        // },
        // network: "monad_testnet",
        // chainId: 10143,
        // urls: {
        //   enabled: true,
        //   apiURL: "https://sourcify-api-monad.blockvision.org",
        //   browserURL: "https://testnet.monadexplorer.com"
        // },
        // network: "hyperliquid",
        // chainId: 998,
        // urls: {
        //   apiURL: "https://api.hyperliquid-testnet.xyz", 
        //   browserURL: "https://api.hyperliquid-testnet.xyz/evm"
        // },



        network: "bepolia",
        chainId: 80069,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/80069/etherscan",
          browserURL: "https://bepolia.beratrail.io"
        },

        // network: "iota",
        // chainId: 8822,
        // urls: {
        //   apiURL: "https://explorer.evm.iota.org/api",
        //   browserURL: "https://explorer.evm.iota.org"
        // },



        // network: "unichain_sepolia",
        // chainId: 1301,
        // urls: {
        //   apiURL: "https://sepolia.unichain.org", 
        //   browserURL: "https://sepolia.uniscan.xyz/"  
        // },

        // network: "worldchain_testnet",
        // chainId: 4801,
        // urls: {
        //   enabled: true,
        //   apiURL: "https://api-sepolia.worldscan.org/api",
        //   browserURL: "https://sepolia.worldscan.org/"
        // },

        // network: "gravity_testnet",
        // chainId: 13505,
        // urls: {
        //   apiURL: "https://explorer-gravity-alpha-testnet-sepolia-3ggx92odhy.t.conduit.xyz/api",
        //   browserURL: "https://rpc-sepolia.gravity.xyz",
        //   // For Blockscout
        //   // apiURL: "https://explorer.gravity.xyz/api",
        //   // browserURL: "https://explorer.gravity.xyz",
        // },
      }
    ]
  },


  mocha: {
    timeout: 600000,
  },
  defaultNetwork: "hardhat",
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  networks: {
    hardhat: {
      chainId: 1337,
      allowUnlimitedContractSize: true,
    },
    // mainnet: {
    //   accounts: [DEPLOYER_PRIVATE_KEY],
    //   url: "https://mainnet.infura.io/v3/" + INFURA_API_KEY,
    //   chainId: 1,
    //   gasPrice: 15000000000
    // },
    // sepolia: {
    //   accounts: [DEPLOYER_PRIVATE_KEY],
    //   url: 'https://sepolia.infura.io/v3/' + INFURA_API_KEY,
    //   chainId: 11155111
    // },
    polygon: {
      url: "https://nd-564-299-754.p2pify.com/e0ba3b0dcc379469efeb4766c010ca7f",
      chainId: 137,
      gasPrice: 180000000000,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    mumbai: {
      // url: 'https://rpc.ankr.com/polygon_mumbai',
      // url:'https://polygon-mumbai.infura.io/v3/' + INFURA_API_KEY,
      // url:'https://polygon-mumbai.infura.io/v3/' + INFURA_API_KEY,
      // url: 'https://polygon-mumbai.infura.io/v3/'+ INFURA_API_KEY,
      url: 'https://rpc-mumbai.maticvigil.com/',
      url: 'https://polygon-mumbai.infura.io/v3/' + INFURA_API_KEY,

      chainId: 80001,
      // gasPrice: 18000000000,
      accounts: [DEPLOYER_PRIVATE_KEY],
      timeout: 600000
    },
    amoy: {
      url: "https://rpc-amoy.polygon.technology/",
      chainId: 80002,
      gasPrice: 98667450049,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },

    artela: {
      url: "https://betanet-rpc1.artela.network",
      chainId: 11822,
      gasPrice: 20,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    unichain_sepolia: {
      url: "https://sepolia.unichain.org",
      chainId: 1301,
      gasPrice: 1000252,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    bsc: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 56,
      url: "https://bsc-mainnet.core.chainstack.com/5645bf71858cf2d4ea212eca158f460c",
      gasPrice: 3000000000
    },
    tbsc: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 97,
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
    },
    arbitrum: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 42161,
      url: "https://nd-026-478-739.p2pify.com/b514dec27de9382c4c59f1ea6deb059c",
    },
    arbitrum_goerli: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 421613,
      url: "https://endpoints.omniatech.io/v1/arbitrum/goerli/public",
    },
    optimism: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 10,
      url: "https://nd-412-249-485.p2pify.com/8d0954f781e4dcbb50fbcdb18ab7cbbd",
    },
    optimism_goerli: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 420,
      url: "https://endpoints.omniatech.io/v1/op/goerli/public",
    },
    blast: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 81457,
      url: "https://rpc.blast.io",
    },
    artio: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 80085,
      url: "https://rpc.ankr.com/berachain_testnet",
    },
    blast_sepolia: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 168587773,
      url: "https://blast-sepolia.drpc.org",
    },
    base: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 8453,
      url: "https://base.llamarpc.com",
      gasPrice: 34000000
    },
    base_sepolia: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 84532,
      url: "https://nameless-cosmopolitan-sheet.base-sepolia.quiknode.pro/2ee8b004de048ca37436abe795878f40c5342cf5",
    },
    bepolia: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 80069,
      url: "https://bepolia.rpc.berachain.com/"
    },
    berachain: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 80094,
      url: "https://rpc.berachain.com/"
    },
    iota: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 8822,
      url: "https://json-rpc.evm.iotaledger.net",
    },
    hyperliquid: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 998,
      url: "https://api.hyperliquid-testnet.xyz/evm",
    },
    monad_testnet: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 10143,
      url: "https://testnet-rpc.monad.xyz",
      gasPrice: 50000000000,
      timeout: 600000
    },
    somnia_testnet: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 50312,
      url: "https://dream-rpc.somnia.network",
      // gasPrice: 30000000000,
      timeout: 600000
    },
    worldchain_testnet: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 4801,
      url: "https://nameless-cosmopolitan-sheet.worldchain-sepolia.quiknode.pro/2ee8b004de048ca37436abe795878f40c5342cf5",
      gasPrice: 1000250
    },
    gravity_testnet: {
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 13505,
      url: "https://rpc-sepolia.gravity.xyz",
    },
    // gravity_devnet: {
    //   accounts: [DEPLOYER_PRIVATE_KEY],
    //   chainId: 7771625,
    //   url: "https://rpc-devnet.gravity.xyz/"
    // }
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  paths: {
    artifacts: "artifacts",
    cache: "cache",
    deploy: "deploy",
    deployments: "deployments",
    imports: "imports",
    sources: "contracts",
    tests: "test",
  },
};

