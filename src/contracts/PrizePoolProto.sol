// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract PrizePoolProto is Ownable {
    using ECDSA for bytes32;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    enum SeasonStatus {
        Active,
        Claim,
        Inactive
    }

    SeasonStatus private _seasonStatus;
    address private trustedSigner;
    uint256 private totalUsersScore;
    uint256 private prizePool = 1 ether;
    uint256 private claimPeriod = 3 days;
    uint private _seasonStartDate;
    uint private _seasonDuration = 30 days;

    mapping(address => uint256) private _nonces;
    mapping(bytes => bool) private _executed;
    EnumerableMap.AddressToUintMap private _scores;

    event SeasonStatusChanged(SeasonStatus status, uint256 ts);

    constructor(address _trustedSigner) Ownable() {
        trustedSigner = _trustedSigner;
    }

    function startSeason() external onlyOwner {
        _seasonStartDate = block.timestamp;
        _seasonStatus = SeasonStatus.Active;
        emit SeasonStatusChanged(_seasonStatus, block.timestamp);
    }

    function stopSeason() external onlyOwner {
        _seasonStatus = SeasonStatus.Inactive;
        resetSeason();
        emit SeasonStatusChanged(_seasonStatus, block.timestamp);
    }

    function seasonIsActive() public view returns (bool) {
        return _seasonStatus == SeasonStatus.Active && _seasonDuration > 0 && block.timestamp < (_seasonStartDate + _seasonDuration);
    }

    function getSeasonStartDate() public view returns (uint256) {
        return _seasonStartDate;
    }

    /**
     * @notice Increment user score by a provided amount
     */
    function addScore(address user, uint256 amount, bytes memory signature) public onlyOwner {
        require(seasonIsActive(), "addScore: Season is not active at the moment!");
        require(_verify(user, amount, _nonces[user]++, signature), "addScore: Sig verification failed!");

        require(!_executed[signature], "addScore: Provided signature has already been used!");
        _executed[signature] = true;

        totalUsersScore += amount;

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
        require(seasonIsActive(), "claimRewards: Season is not active at the moment!");
        require(_scores.contains(msg.sender), "claimRewards: Non-existing user!");

        uint256 score = _scores.get(msg.sender);
        require(score > 0, "claimRewards: User must have some score to claim reward!");

        // uint256 userShareReward = score / totalUsersScore;
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
     */
    function _verify(
        address user,
        uint256 amount,
        uint256 nonce,
        bytes memory signature
    ) private view returns (bool) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(user, amount, nonce)).toEthSignedMessageHash();
        // TODO: Decide on how we construct data string that is being signed on the backend
        (address recoveredSigner, ECDSA.RecoverError recoverError) = ethSignedMessageHash.tryRecover(signature);
        require(recoverError == ECDSA.RecoverError.NoError, "_verify: ECDSA signature couldn't be verified!");
        require(recoveredSigner == trustedSigner, "_verify: Data signed by unstrusted signer!");
        return true;
    }

    function resetSeason() internal {
        for (uint i = 0; i < _scores.length(); i++) {
            (address user, uint256 score) = _scores.at(i);

            if (score != 0) {
                _scores.set(user, 0);
            }
        }

        totalUsersScore = 0;
    }
}