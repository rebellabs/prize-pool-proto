// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SampleNFT is Ownable {
    using ECDSA for bytes32;

    address public trustedSigner;

    // This mapping will keep the scores of users
    mapping(address => uint) private _scores;

    constructor() ERC721("Prize Pool Prototype", "PPP") {
        // Nothing here for now, should prolly set the signer at the start though
    }

    /**
     * @notice Setter for trusted metadata signer
     * @param signer Public ethereum address of a trusted signer
     */
    function _setSigner(address signer) public onlyOwner {
        trustedSigner = signer;
    }

    /**
     * @notice Increment user score by a provided amount
     */
    function addScore(address user, uint amount, bytes signature) public {
        string data = "Construct string to sign somehow from amount and user";
        require(_verify(data, signature));
        if (_scores[user] == 0) {
            _scores[user] = amount;
        } else {
            _scores[user] += amount;
        }
    }

    /**
     * @dev WIP - draft
     */
    function claimRewards() public {
        require(msg.sender.balance > 0, "User must have some score to claim reward!");
    }

    /**
     * @dev WIP - draft
     */
    function getUserReward(address user) public {
        return _scores[user];
    }

    /**
     * @notice Verifies that the provided signature was produced by the correct signer from the given message
     * @param metadata string containing the ceramic stream ID
     * @param signature backend-produced signature to verify the correctness of metadata
     */
    function _verify(
        string memory data,
        bytes memory signature
    ) private view returns (bool) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(metadata)).toEthSignedMessageHash();
        (address recoveredSigner, ECDSA.RecoverError recoverError) = ethSignedMessageHash.tryRecover(signature);
        require(recoverError == ECDSA.RecoverError.NoError);
        require(recoveredSigner == metadataSigner, "Data signed by unstrusted signer");
        return true;
    }
}