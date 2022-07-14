// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../contracts/SampleNFT.sol";

contract SharedTestSetup is Test {

    SampleNFT sampleNFT = new SampleNFT();

    uint256 internal TOTAL_SUPPLY = sampleNFT.TOTAL_SUPPLY();
    uint256 internal MINT_PRICE = sampleNFT.MINT_PRICE();

    // Hardcoded metadata URI string and bytes signature - to emulate signing in ethers.js
    string internal metadataURI = "b847d995e7b0c31be86fdb5169ae5faedf35c234e9df079a7222064a6a4a";
    bytes internal signature = hex"5c693cc854ed60102753102d3045b88816dc76e98d5f5cdccef86b6a2edfd0f15e84dad6a6dc277321eb6569f704f2d4641160ef6e43086a930ccd1b12b18c061c";

    // Global verbosity of tests - switch on and off
    bool internal verbosity = true;

    // Use this nonce accross different test contracts to securely generate pseudorandom addresses
    uint internal sharedNonce = 0;

    /**
     * @notice Asserts that the provided address has minted an NFT and has a balance 1 or greater
     */
    function assertMint(address user) public {
        uint addressBalance = sampleNFT.balanceOf(user);
        assertGt(addressBalance, 0);
    }

    /**
     * @notice Output provided test description to CLI
     * @dev supply -vv or more verbose flag to see logs 
     */
    function emitTestDescription(string memory description, bool v) internal {
        if (v == true) {
            emit log(" "); // New line for better readability in CL
            emit log(description);
        }
    }

    /**
     * @notice Generate random 0x address and set its balance to 10 $ETH
     */
    function getRandomAddress(uint nonce) internal returns (address) {
            // Generate random address 
            address randomAddress = address(uint160(uint(keccak256(abi.encodePacked(nonce, blockhash(block.number))))));

            // Top up the address with some ETH
            vm.deal(randomAddress, 10 ether);

            // Increment shared nonce
            sharedNonce++;

            return randomAddress;
    }
}