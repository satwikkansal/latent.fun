const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Add test judges - replace with actual judge addresses
  const judges = [
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
  ];

  const TalentShow = await ethers.getContractFactory("TalentShow");

  // Deploy with both required constructor arguments
  const talentShow = await TalentShow.deploy(
    deployer.address,  // initialOwner
    judges            // judges array
  );

  await talentShow.deployed();

  console.log("TalentShow deployed to:", talentShow.address);
  console.log("Owner:", deployer.address);
  console.log("Judges:", judges);

  // Verify contract
  console.log("Waiting for block confirmations...");
  await talentShow.deployTransaction.wait(6); // wait for 6 block confirmations

  console.log("Verifying contract...");
  try {
    await run("verify:verify", {
      address: talentShow.address,
      constructorArguments: [deployer.address, judges],
    });
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("Already verified!");
    } else {
      console.error("Error verifying contract:", e);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });