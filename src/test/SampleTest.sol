// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "./SharedTestSetup.sol";

contract SampleTest is SharedTestSetup {
    function testCan() public {
        // emitTestDescription("Users can mint and receive an NFT for declared price.", verbosity);

        // // Get random address
        // address randomAddress = getRandomAddress(sharedNonce);

        // // Now mint one   
        // vm.prank(randomAddress);
        // sampleNFT.payToMint{value: MINT_PRICE}(metadataURI, signature);

        // assertMint(randomAddress);
    }
}
