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
  const talentShow = await TalentShow.deploy(judges);
  await talentShow.deployed();

  console.log("TalentShow deployed to:", talentShow.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });