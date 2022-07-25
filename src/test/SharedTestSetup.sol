// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../contracts/PrizePoolProto.sol";

contract SharedTestSetup is Test {
    using ECDSA for bytes32;

    PrizePoolProto prizePool = new PrizePoolProto(address(777));

    // uint256 internal TOTAL_SUPPLY = sampleNFT.TOTAL_SUPPLY();
    // uint256 internal MINT_PRICE = sampleNFT.MINT_PRICE();

    // Leaving that here for future reference with ECDSA signatures etc
    // Hardcoded metadata URI string and bytes signature - to emulate signing in ethers.js
    // string internal metadataURI = "b847d995e7b0c31be86fdb5169ae5faedf35c234e9df079a7222064a6a4a";
    // bytes internal signature = hex"5c693cc854ed60102753102d3045b88816dc76e98d5f5cdccef86b6a2edfd0f15e84dad6a6dc277321eb6569f704f2d4641160ef6e43086a930ccd1b12b18c061c";

    // Global verbosity of tests - switch on and off
    bool internal verbosity = true;

    // Use this nonce accross different test contracts to securely generate pseudorandom addresses
    uint internal sharedNonce = 0;

    // Private key of metadata signer - currently hardhat #19 account
    uint256 internal signerPrivateKey = 0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e;

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

    /**
     * @notice Generate and return pseudorandom hex string
     */
    function getRandomString() internal returns (string memory) {
            string memory randString = Strings.toHexString(uint256(keccak256(abi.encodePacked(sharedNonce, blockhash(block.number)))), 32);
            sharedNonce++;
            return randString;
    }

    /**
     * @notice Generate ethers-style signature for a provided string
     */
    function getStringSignature(string memory metadata) internal returns (bytes memory) {
        bytes32 hash = keccak256(abi.encodePacked(metadata));
        bytes32 signedHash = hash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, signedHash);
        return bytes.concat(r, s, abi.encodePacked(v));
    }
}