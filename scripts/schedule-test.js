// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");

async function main() {
	// Hardhat always runs the compile task when running scripts with its command
	// line interface.
	// If this script is run directly using `node` you may want to call compile
	// manually to make sure everything is compiled
	await hre.run('compile');

	const provider = ethers.getDefaultProvider();

	let privateKey = '0x37eeb7639a8837a9ed2d31668a3b525e456d92665e3b2d748250d8d4346b6978';
	let wallet = new ethers.Wallet(privateKey, provider);

	const prizePoolContract = await ethers.getContractFactory("PrizePoolProto");

	const prizePool = await prizePoolContract.attach('0xa5E0e6a46EdB4a52b3A5bf225FDCbBBCA39c5aE8');
	prizePool.connect(wallet);

	try {
		const txstop = await prizePool.stopSeason();
		await txstop.wait();
	} catch {
	}
	const n = new Date();
	n.setSeconds(n.getSeconds() + 30);
	const curr = Date.now()
	const duration = n.getTime() - curr;

	const pool = 100000;

	const tx = await prizePool.scheduleSeason(Math.floor(n.getTime() / 1000), Math.floor(duration / 1000), pool);

	const b = await tx.wait();

	console.log(b);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});

