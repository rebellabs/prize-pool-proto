# Foundry x Hardhat

Use this template for easy setup of a smart contract workstation - combine hardhat and foudry functionality with ease. Using vanilla JS (no typescript, unlike most current alternative templates). 

## Installation 

Follow the [link](https://book.getfoundry.sh/getting-started/installation.html) to make sure you fetch yourself the latest version of foundry. 

## Setup 

```shell
yarn install
forge install
```

## Available Commands 

Hardhat functionality cookbook:

```shell
yarn hardhat compile
yarn hardhat test
```

In order to run a ganache local node and deploy your contract you can use the following: 

```shell
yarn hardhat node 
yarn hardhat run scripts/deploy-samplenft.js --network localhost
```

Forge:

```
forge build
forge test
```

To forge tests with higher verbosity use `-vvv` flag (prints out traces for failing tests), and `-vvvv` for max verbosity.

To run gas report use `--gas-report`

## Key Directory Structure 

```
.
├── 📂 artifacts/ - build artifacts produced by hardhat
├── 📂 lib/ - foundry dependencies (as git submodules)
├── 📂 node_modules/ - hardhat npm style dependencies 
├── 📂 out/ - build artifacts produced by forge
├── 📂 scripts/ - hardhat scripts
├── 📂 src/
│   ├── 📂 contracts/ - contracts source code
│   └── 📂 test/ - foundry Solidity tests
├── 📂 test/ - hardhat JS/TS tests
```
