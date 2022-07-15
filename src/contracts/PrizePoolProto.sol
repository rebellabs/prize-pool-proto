// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PrizePoolProto is Ownable {
    using ECDSA for bytes32;

    address public trustedSigner;

    // This mapping will keep the scores of users
    mapping(address => uint) private _scores;

    // This will keep the timestamp of the season start + duration
    uint private _seasonStartDate;
    uint private _seasonDuration = 30 days;

    constructor() Ownable() {
        // Nothing here for now, should prolly set the signer at the start though
    }

    /**
     * @notice Saves the timestamp of season start 
     */
    function _startSeason() public onlyOwner {
        _seasonStartDate = block.timestamp;
    }

    /**
     * @notice Increment user score by a provided amount
     */
    function addScore(address user, uint amount, bytes memory signature) public {
        string memory data = "Construct string to sign somehow from amount and user";
        require(_verify(data, signature));
        if (_scores[user] == 0) {
            _scores[user] = amount;
        } else {
            _scores[user] += amount;
        }
    }

    /**
     * @notice Allows anyone to claim reward if they have any available
     */
    function claimRewards() public {
        require(_seasonDuration > 0, "Need to set the season duration first!");
        require(block.timestamp >= _seasonStartDate + _seasonDuration, "Season isn't over yet!");
        require(msg.sender.balance > 0, "User must have some score to claim reward!");
        // Pay out expected reward to the user 
        // Make payable
    }

    /**
     * @notice Returns rewards amount for a user
     */
    function getUserReward(address user) public view returns (uint) {
        return _scores[user];
    }

    /**
     * @notice Setter for trusted metadata signer
     * @param signer Public ethereum address of a trusted signer
     */
    function _setSigner(address signer) public onlyOwner {
        trustedSigner = signer;
    }

    /**
     * @notice Setter for season duration
     */
    function _setDuration(uint amount) public onlyOwner {
        _seasonDuration = amount;
    }

    /**
     * @notice Verifies that the provided signature was produced by the correct signer from the given message
     * @param data data to be signed
     * @param signature backend-produced signature to verify the trustworthyness of data
     */
    function _verify(
        string memory data,
        bytes memory signature
    ) private view returns (bool) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(data)).toEthSignedMessageHash();
        (address recoveredSigner, ECDSA.RecoverError recoverError) = ethSignedMessageHash.tryRecover(signature);
        require(recoverError == ECDSA.RecoverError.NoError);
        require(recoveredSigner == trustedSigner, "Data signed by unstrusted signer");
        return true;
    }
}