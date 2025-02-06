// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const { getContracts, saveContract } = require("../utils");

const JAN_1ST_2030 = 1893456000;
const ONE_GWEI = 1_000_000_000n;

module.exports = buildModule("LockModule", (m) => {
  const network = m.getParameter("network", "berachain");
  const contracts = getContracts(network);

  console.log("contracts", contracts);

  // Deploy RocketBera behind a proxy
  const rocket = m.contractAt("RocketBera", [], {
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          contracts.platform,
          contracts.platformFee,
          contracts.feeAddr,
          contracts.fee,
          contracts.routerV2,
          contracts.blockInterval,
          contracts.minCap
        ]
      }
    }
  });

  return { rocket };
});
