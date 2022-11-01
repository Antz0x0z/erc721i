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
  const { owner } = await getNamedAccounts();
  const network = await hre.network;
  const deployData = {};

  let tx, receipt;
  const chainId = chainIdByName(network.name);

  const demoBaseUri = process.env.NFT_BASE_URI || "";
  const demoMaxSupply = "61";

  console.log("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  console.log("Infinite (ERC721i) Contract Deployment");
  console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");

  console.log(`  Using Network: ${chainNameById(chainId)} (${network.name}:${chainId})`);
  console.log("  Using Owner:  ", owner);
  console.log(" ");

  //
  // Demo Deploy & Pre-Mint
  //
  console.log("\nDeploying...");
  console.log("~~~~~~~~~~~~~~~~~");
  const constructorArgs = ["ERC721 Demo Halloween Ghost", "GHST", demoBaseUri, demoMaxSupply];
  const DemoNFT = await ethers.getContractFactory("ContractOnCEMNetwork");
  const DemoNFTInstance = await DemoNFT.deploy(...constructorArgs);
  const demoNFT = await DemoNFTInstance.deployed();
  deployData['ContractOnCEMNetwork'] = {
    abi: getContractAbi('ContractOnCEMNetwork'),
    address: demoNFT.address,
    deployTransaction: demoNFT.deployTransaction,
    constructorArgs,
  }
  saveDeploymentData(chainId, deployData);
  console.log("  - DemoNFT: ", demoNFT.address);
  console.log("     - Gas Cost:   ", getEstimatedTxGasCost({ deployTransaction: demoNFT.deployTransaction }));

  console.log(`\n  Pre-Minting a ${demoMaxSupply} NFTs...`);
  tx = await demoNFT.preMint();
  receipt = await tx.wait();
  console.log("     - Gas Cost: ", getActualTxGasCost({ deployTransaction: receipt }));

  console.log("\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  console.log("\n  Contract Deployment Complete.");
  console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");

  console.log("Next messages: ...");
  console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");
  let listedItemsCount = await demoNFT.listedItemsCount();
  console.log("listedItemsCount: ",listedItemsCount);
  let getURI = await demoNFT.getURI(5);
  console.log("getURI: ",getURI);
  let tokenOfOwnerByIndex = await demoNFT.tokenOfOwnerByIndex(owner, 1);
  console.log("tokenOfOwnerByIndex: ",tokenOfOwnerByIndex);
  console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
