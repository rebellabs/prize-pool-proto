// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract PrizePoolProto is Ownable {
    using ECDSA for bytes32;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    enum SeasonStatus {
        Active,
        Claim,
        Inactive,
        Scheduled
    }

    enum SeasonDuration {// or let admin choose arbitrary season duration
        Day,
        Week,
        Month
    }
    SeasonStatus private _seasonStatus;

    address private trustedSigner;

    uint256 private totalUsersScore;
    uint256 private prizePool = 1 ether;
    uint256 private claimPeriod = 3 days;
    uint private _seasonStartDate;
    uint private _seasonFinishDate;
    uint private _seasonDuration = 30 days;

    mapping(address => uint256) private _nonces;
    mapping(bytes => bool) private _executed;
    EnumerableMap.AddressToUintMap private _scores;

    event SeasonStatusChanged(SeasonStatus status, uint256 ts);
    event UserRewardClaimed(address user, uint256 amount);

    constructor(address _trustedSigner) Ownable() {
        trustedSigner = _trustedSigner;
    }

    function scheduleSeason(uint256 timestamp, /*SeasonDuration*/uint256 dur) external onlyOwner {
        _seasonStartDate = timestamp;
        _seasonFinishDate = timestamp + dur;
        _seasonStatus = SeasonStatus.Scheduled;
        _seasonDuration = dur;

        emitSeasonStatusChanged(_seasonStatus);
    }

    function startSeason() external onlyOwner {
        if (!seasonIsActive()) {
            revert("startSeason: Season is already active");
        }
        _seasonStatus = SeasonStatus.Active;

        emitSeasonStatusChanged(_seasonStatus);
    }

    function stopSeason() external onlyOwner {
        _seasonStatus = SeasonStatus.Inactive;
        resetSeason();

        emitSeasonStatusChanged(_seasonStatus);
    }

    function startClaimPeriod() external onlyOwner {
        _seasonStatus = SeasonStatus.Claim;
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
    function addScore(address user, uint256 amount, uint256 nonce, bytes memory signature) public onlyOwner {
        require(seasonIsActive(), "addScore: Season is not active at the moment!");
        require(_verify(user, amount, nonce, signature), "addScore: Sig verification failed!");
        _nonces[user]++;
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
    function claimReward() external {
        require(seasonIsActive(), "claimRewards: Season is not active at the moment!");
        address addr = msg.sender;
        require(_scores.contains(addr), "claimRewards: Non-existing user!");

        uint256 score = _scores.get(addr);
        require(score > 0, "claimRewards: User must have some score to claim reward!");

        _scores.set(addr, 0);

        emit UserRewardClaimed(msg.sender, score);
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

    function getUserNonce(address user) external view returns (uint256) {
        return _nonces[user];
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

    function emitSeasonStatusChanged(SeasonStatus status) internal {
        emit SeasonStatusChanged(status, block.timestamp);
    }
}