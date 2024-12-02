const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TalentShow", function () {
  let TalentShow;
  let talentShow;
  let owner;
  let judge1;
  let judge2;
  let performer;
  let audience1;
  let audience2;
  const stakeAmount = ethers.utils.parseEther("1");

  beforeEach(async function () {
    // Get signers
    [owner, judge1, judge2, performer, audience1, audience2] = await ethers.getSigners();

    // Deploy contract
    const TalentShow = await ethers.getContractFactory("TalentShow");
    const judgeAddresses = [judge1.address, judge2.address];
    talentShow = await TalentShow.deploy(owner.address, judgeAddresses);
    await talentShow.deployed();
  });

  describe("Initialization", function () {
    it("Should set the correct judges", async function () {
      expect(await talentShow.judges(0)).to.equal(judge1.address);
      expect(await talentShow.judges(1)).to.equal(judge2.address);
      expect(await talentShow.isJudge(judge1.address)).to.be.true;
      expect(await talentShow.isJudge(judge2.address)).to.be.true;
    });

    it("Should set the correct owner", async function () {
      expect(await talentShow.owner()).to.equal(owner.address);
    });
  });

  describe("Performance Submission", function () {
    it("Should allow performance submission with correct stake", async function () {
        const tx = await talentShow.connect(performer).submitPerformance(
            "video_link",
            8,
            { value: stakeAmount }
        );

        const receipt = await tx.wait();
        const event = receipt.events.find(e => e.event === 'PerformanceSubmitted');

        // Verify event was emitted with correct data
        expect(event.args.performanceId).to.equal(1);
        expect(event.args.performer).to.equal(performer.address);
        expect(event.args.videoLink).to.equal("video_link");

        // Verify timestamp is within a reasonable range (1 second)
        const blockTimestamp = await getBlockTimestamp();
        expect(event.args.timestamp).to.be.closeTo(blockTimestamp, 1);

        // Verify performance details
        const performance = await talentShow.getPerformanceDetails(1);
        expect(performance.performer).to.equal(performer.address);
        expect(performance.videoLink).to.equal("video_link");
        expect(performance.selfScore).to.equal(8);
    });

    it("Should reject performance submission with incorrect stake", async function () {
      await expect(
        talentShow.connect(performer).submitPerformance(
          "video_link",
          8,
          { value: ethers.utils.parseEther("0.5") }
        )
      ).to.be.revertedWith("Incorrect stake amount");
    });
  });

  describe("Audience Voting", function () {
    beforeEach(async function () {
      await talentShow.connect(performer).submitPerformance(
        "video_link",
        8,
        { value: stakeAmount }
      );
    });

    it("Should allow audience voting with correct stake", async function () {
      await expect(
        talentShow.connect(audience1).submitAudienceScore(
          1,
          7,
          { value: stakeAmount }
        )
      )
        .to.emit(talentShow, "ScoreSubmitted")
        .withArgs(1, audience1.address, 7, false);

      const audienceScore = await talentShow.getAudienceScore(1, audience1.address);
      expect(audienceScore).to.equal(7);
    });

    it("Should prevent double voting by audience", async function () {
      await talentShow.connect(audience1).submitAudienceScore(
        1,
        7,
        { value: stakeAmount }
      );

      await expect(
        talentShow.connect(audience1).submitAudienceScore(
          1,
          8,
          { value: stakeAmount }
        )
      ).to.be.revertedWith("Already voted");
    });
  });

  describe("Judge Voting", function () {
    beforeEach(async function () {
      await talentShow.connect(performer).submitPerformance(
        "video_link",
        8,
        { value: stakeAmount }
      );
      // Fast forward time to after voting window
      await network.provider.send("evm_increaseTime", [86401]); // 24 hours + 1 second
      await network.provider.send("evm_mine");
    });

    it("Should allow judges to vote after voting window", async function () {
      await expect(talentShow.connect(judge1).submitJudgeScore(1, 8))
        .to.emit(talentShow, "ScoreSubmitted")
        .withArgs(1, judge1.address, 8, true);

      const scores = await talentShow.getJudgesScore(1);
      expect(scores[0]).to.equal(8);
    });

    it("Should prevent non-judges from voting", async function () {
      await expect(
        talentShow.connect(audience1).submitJudgeScore(1, 8)
      ).to.be.revertedWith("Not a judge");
    });
  });

  describe("Reward Distribution", function () {
    beforeEach(async function () {
      await talentShow.connect(performer).submitPerformance(
        "video_link",
        8,
        { value: stakeAmount }
      );

      await talentShow.connect(audience1).submitAudienceScore(
        1,
        8,
        { value: stakeAmount }
      );

      await network.provider.send("evm_increaseTime", [86401]);
      await network.provider.send("evm_mine");

      await talentShow.connect(judge1).submitJudgeScore(1, 8);
      await talentShow.connect(judge2).submitJudgeScore(1, 8);
    });

    it("Should distribute rewards correctly when performer guesses correctly", async function () {
      const initialBalance = await performer.getBalance();

      await talentShow.distributeRewards(1);

      const finalBalance = await performer.getBalance();
      expect(finalBalance.sub(initialBalance)).to.be.above(0);
    });

    it("Should prevent double reward distribution", async function () {
      await talentShow.distributeRewards(1);
      await expect(talentShow.distributeRewards(1))
        .to.be.revertedWith("Rewards already claimed");
    });
  });

  // Helper function to get current block timestamp
  async function getBlockTimestamp() {
    const block = await ethers.provider.getBlock("latest");
    return block.timestamp;
  }
});