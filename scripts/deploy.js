// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers} = require("hardhat");

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    await hre.run('compile');

    const [deployer] = await ethers.getSigners();

    console.log('Deployer: ', deployer.address);
    // We get the contract to deploy
    const prizePoolContract = await ethers.getContractFactory("PrizePoolProto");

    const DAY = 60 * 60 * 24;

    // const minSeasonDuration = DAY;
    // const maxSeasonDuration = DAY * 4;
    //
    // const minClaimPeriodDuration = DAY;
    // const maxClaimPeriodDuration = DAY * 3;

    const prizePool = await prizePoolContract.deploy(
        deployer.address,
        300,// minSeasonDuration,
        300,// maxSeasonDuration,
        300,// minClaimPeriodDuration,
        300// maxClaimPeriodDuration
    );

    await prizePool.deployed();

    console.log("PrizePool deployed to:", prizePool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

