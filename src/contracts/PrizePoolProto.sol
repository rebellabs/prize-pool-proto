// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract PrizePoolProto is Ownable {
    using ECDSA for bytes32;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    address public trustedSigner;

    mapping(address => uint256) private _nonces;
    // This mapping will keep the scores of users
    EnumerableMap.AddressToUintMap private _scores;

    enum SeasonStatus {
        Active,
        Claim,
        Inactive
    }
    SeasonStatus private _seasonStatus;

    // This will keep the timestamp of the season start + duration
    uint private _seasonStartDate;
    uint private _seasonDuration = 30 days;

    constructor() Ownable() {
        // Nothing here for now, should prolly set the signer at the start though
    }

    function startSeason() external onlyOwner {
        _seasonStartDate = block.timestamp;
        _seasonStatus = SeasonStatus.Active;
    }

    function stopSeason() external onlyOwner {
        _seasonStatus = SeasonStatus.Inactive;
    }

    function resetSeason() external onlyOwner {
        for (uint i = 0; i < _scores.length(); i++) {
            (address user, uint256 score) = _scores.at(i);

            if (score != 0) {
                _scores.set(user, 0);
            }
        }
    }

    function seasonIsActive() public view returns (bool) {
        return _seasonStatus == SeasonStatus.Active;
    }

    function getSeasonStartDate() public view returns (uint256) {
        return _seasonStartDate;
    }

    /**
     * @notice Increment user score by a provided amount
     */
    function addScore(address user, uint256 amount, bytes memory signature) public onlyOwner {
        require(seasonIsActive(), "addScore: Season is not active at the moment");
        require(_verify(user, amount, _nonces[user]++, signature), "addScore: Sig verification failed");

        require(!executed[signature], "addScore: Provided signature has already been used");
        executed[signature] = true;

        if (_scores.contains(user)) {
            _scores.set(user, _scores.get(user) + amount);
        } else {
            _scores.set(user, amount);
        }
    }

    /**
     * @notice Allows anyone to claim reward if they have any available
     */
    function claimRewards() public payable {
        require(seasonIsActive(), "claimRewards: Season is not active at the moment");
        require(_scores.contains(msg.sender), "claimRewards: Non-existing user");
        require(_scores.get(msg.sender) > 0, "claimRewards: User must have some score to claim reward!");
    }

    /**
     * @notice Returns rewards amount for a user
     */
    function getUserReward(address user) public view returns (uint) {
        return _scores.get(user);
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
        address user,
        uint256 memory amount,
        uint256 memory nonce,
        bytes memory signature
    ) private view returns (bool) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(user, amount, nonce)).toEthSignedMessageHash();
        (address recoveredSigner, ECDSA.RecoverError recoverError) = ethSignedMessageHash.tryRecover(signature);
        require(recoverError == ECDSA.RecoverError.NoError);
        require(recoveredSigner == trustedSigner, "Data signed by unstrusted signer");
        return true;
    }
}