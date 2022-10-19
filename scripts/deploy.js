const hre = require("hardhat");

const {
  getEstimatedTxGasCost,
  getActualTxGasCost,
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
} = require("./helpers/utils");

async function main() {
  const { ethers, getNamedAccounts } = hre;
  const { owner, user1 } = await getNamedAccounts();
  const network = await hre.network;
  const deployData = {};

  let tx, receipt;
  const chainId = chainIdByName(network.name);

  const demoBaseUri = process.env.NFT_BASE_URI || "";
  const demoMaxSupply = "1"; // 1,000,000,000,000,000,000,000,000,000,000  Pre-Mint What????

  console.log("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  console.log("Infinite (ERC721i) Contract Deployment");
  console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");

  console.log(`  Using Network: ${chainNameById(chainId)} (${network.name}:${chainId})`);
  console.log("  Using Owner:  ", owner);
  console.log(" ");

  //
  // Demo Deploy & Pre-Mint
  //
  console.log("\n\n  Deploying...");
  console.log("~~~~~~~~~~~~~~~~~");
  const constructorArgs = ["ERC721 Demo Token mainnet", "xNFT", demoBaseUri, demoMaxSupply];
  const DemoNFT = await ethers.getContractFactory("DemoNFT");
  const DemoNFTInstance = await DemoNFT.deploy(...constructorArgs);
  const demoNFT = await DemoNFTInstance.deployed();
  deployData['DemoNFT'] = {
    abi: getContractAbi('DemoNFT'),
    address: demoNFT.address,
    deployTransaction: demoNFT.deployTransaction,
    constructorArgs,
  }
  saveDeploymentData(chainId, deployData);
  console.log("  - DemoNFT: ", demoNFT.address);
  console.log("     - Gas Cost:   ", getEstimatedTxGasCost({ deployTransaction: demoNFT.deployTransaction }));

  console.log("\n  Pre-Minting a Gazillion NFTs...");
  tx = await demoNFT.preMint();
  receipt = await tx.wait();
  console.log("     - Gas Cost: ", getActualTxGasCost({ deployTransaction: receipt }));

  console.log("\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  console.log("\n  Contract Deployment Complete.");
  console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
