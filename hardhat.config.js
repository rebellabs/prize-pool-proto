require("@nomiclabs/hardhat-waffle");

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task('scheduleSeason', 'Schedule season start, claim and finish')
    .addParam('contractAddress', 'Contract address of the deployed contract')
    .addParam('privateKey', 'Private key of the trusted signer')
    .setAction(async (args, hre) => {
        const provider = hre.ethers.getDefaultProvider();

        let privateKey = args.privateKey;
        let wallet = new hre.ethers.Wallet(privateKey, provider);

        const prizePool = await hre.ethers.getContractAt("PrizePoolProto", args.contractAddress);
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
    });

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.9",
    networks: {
        hardhat: {
            chainId: 1337,
            gasPrice: 900000000,
            accounts: {
                count: 20
            }
        },
        localhost: {
            gasPrice: 900000000,
            url: 'http://127.0.0.1:7545'
        }
    },
    paths: {
        sources: "./src/contracts",
    },
};
