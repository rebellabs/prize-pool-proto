// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PrizePoolProto is Ownable {
    using ECDSA for bytes32;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    enum SeasonStatus {
        Active,
        Claim,
        Inactive,
        Scheduled
    }

    SeasonStatus private _seasonStatus = SeasonStatus.Inactive;

    address private _trustedSigner;

    address private _rewardsToken;

    uint256 private _totalUsersScore;
    uint256 private _prizePool; // TODO: Decide on default values of all global vars
    uint256 private _seasonStartDate;
    uint256 private _seasonFinishDate;

    uint256 private _claimPeriodDuration;
    uint256 private _seasonDuration;

    uint256 private  _minSeasonDuration = 1 days;
    uint256 private _maxSeasonDuration = 12 weeks;
    uint256 private _minClaimPeriodDuration = 1 days;
    uint256 private _maxClaimPeriodDuration = 5 days;

    mapping(address => uint256) private _nonces; //TODO use Enumerable map?
    mapping(bytes => bool) private _executed; //TODO use Enumerable map?
    EnumerableMap.AddressToUintMap private _scores;

    event SeasonScheduled(uint256 startDate, uint256 duration, uint256 _prizePool);
    event SeasonStatusChanged(SeasonStatus status, uint256 ts);
    event UserRewardClaimed(address user, uint256 amount);

    modifier onlySeasonStatus(SeasonStatus status) {
        require(_seasonStatus == status);
        _;
    }

    constructor(
        address _signer,
        uint256 minSeasonDuration,
        uint256 maxSeasonDuration,
        uint256 minClaimPeriodDuration,
        uint256 maxClaimPeriodDuration
    ) Ownable() {
        _trustedSigner = _signer;
        _minSeasonDuration = minSeasonDuration;
        _maxSeasonDuration = maxSeasonDuration;
        _minClaimPeriodDuration = minClaimPeriodDuration;
        _maxClaimPeriodDuration = maxClaimPeriodDuration;
    }

    /**
     * @notice Schedule a season to start at a timestamp in the future
     */
    function scheduleSeason(
        uint256 startDate,
        uint256 seasonDuration,
        uint256 claimPeriodDuration,
        uint256 prizePool
    ) external
    onlyOwner
    onlySeasonStatus(SeasonStatus.Inactive)
    {
        require(prizePool > 0, "Big prizes only!");
        require(startDate > block.timestamp, "Start time should be in the future!");
        require(seasonDuration > _minSeasonDuration, "Season duration below minimal value!");
        require(seasonDuration <= _maxSeasonDuration, "Season duration above maximum value!");
        require(claimPeriodDuration > _minClaimPeriodDuration, "Season duration below minimal value!");
        require(claimPeriodDuration <= _maxClaimPeriodDuration, "Season duration below minimal value!");

        _seasonStartDate = startDate;
        _seasonFinishDate = startDate + seasonDuration;
        _prizePool = prizePool;
        _seasonStatus = SeasonStatus.Scheduled;
        _seasonDuration = seasonDuration;

        emit SeasonScheduled(startDate, seasonDuration, prizePool);
        // TODO can we unify this event emition with emitSeasonStatusChanged()?
    }

    /**
     * @notice Activate season from scheduled state (Claim -> Active)
     */
    function startSeason() external
    onlyOwner
    onlySeasonStatus(SeasonStatus.Scheduled)
    {
        require(block.timestamp >= _seasonStartDate, "Cannot start season before the scheduled time!");
        _seasonStatus = SeasonStatus.Active;
        _seasonStartDate = block.timestamp;
        emitSeasonStatusChanged(_seasonStatus);
    }

    /**
     * @notice Stop or un-schedule the season if it's necessary
     */
    function stopSeason() external
    onlyOwner
    {
        //        require(_seasonStatus != SeasonStatus.Claim, "Cannot stop and reset in the claim period!");
        //        require(_seasonStatus != SeasonStatus.Inactive, "Cannot stop an inactive season!");
        _seasonStatus = SeasonStatus.Inactive;
        resetSeason();
        emitSeasonStatusChanged(_seasonStatus);
    }

    /**
     * @notice Open reward claim period for players
     */
    function startClaimPeriod() external
    onlyOwner
    onlySeasonStatus(SeasonStatus.Active)
    {
        _seasonStatus = SeasonStatus.Claim;

        emitSeasonStatusChanged(_seasonStatus);
    }

    function getSeasonStatus() external view returns (uint) {
        return uint(_seasonStatus);
    }

    function getSeasonStartDate() external view returns (uint256) {
        return _seasonStartDate;
    }

    function getSeasonFinishDate() external view returns (uint256) {
        return _seasonFinishDate;
    }

    function getClaimPeriodDuration() external view returns (uint256) {
        return _claimPeriodDuration;
    }

    function getUserNonce(address user) external view returns (uint256) {
        return _nonces[user];
    }

    /**
     * @notice Increment user score by a provided amount
     */
    function addScore(address user, uint256 amount, uint256 nonce, bytes memory signature) external
    onlyOwner
    onlySeasonStatus(SeasonStatus.Active)
    {
        require(_verify(user, amount, nonce, signature), "addScore: Sig verification failed!");
        _nonces[user]++;
        require(!_executed[signature], "addScore: Provided signature has already been used!");
        _executed[signature] = true;

        _totalUsersScore += amount;

        if (_scores.contains(user)) {
            _scores.set(user, _scores.get(user) + amount);
        } else {
            _scores.set(user, amount);
        }
    }

    /**
     * @notice Allows anyone to claim reward if they have any available
     */
    function claimReward() external
    onlySeasonStatus(SeasonStatus.Claim)
    {
        address payable addr = payable(msg.sender);
        require(_scores.contains(addr), "claimRewards: Non-existing user!");

        uint256 score = _scores.get(addr);
        require(score > 0, "claimRewards: User must have some score to claim reward!");

        _scores.set(addr, 0);

        if (_rewardsToken == address(0)) {
            uint value = _prizePool * getUserPoolPercentage(addr);
            addr.transfer(value);
        } else {
            uint value = _prizePool * getUserPoolPercentage(addr);
            IERC20(_rewardsToken).transfer(addr, value);
        }

        emit UserRewardClaimed(msg.sender, score);
    }

    /**
     * @notice Returns user's raw score
     */
    function getUserScore(address user) public view returns (uint) {
        return _scores.get(user);
    }

    /**
     * @notice Get user's share/percentage of the entire prize pool
     */
    function getUserPoolPercentage(address user) public view returns (uint) {
        uint userScore = getUserScore(user);
        return (userScore / _totalUsersScore);
    }

    /**
     * @notice Setter for trusted metadata signer
     * @param signer Public ethereum address of a trusted signer
     */
    function _setSigner(address signer) public onlyOwner {
        _trustedSigner = signer;
    }

    /**
     * @notice Setter for season duration
     */
    function _setDuration(uint amount) public onlyOwner {
        _seasonDuration = amount;
    }

    /**
     * @notice Set rewards token address
     */
    function _setRewardsToken(address token) public onlyOwner {
        _rewardsToken = token;
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
        require(recoveredSigner == _trustedSigner, "_verify: Data signed by unstrusted signer!");
        return true;
    }

    function resetSeason() internal {
        // TODO: What else needs resetting here?

        for (uint i = 0; i < _scores.length(); i++) {
            (address user,) = _scores.at(i);
            _scores.remove(user);
        }

        _totalUsersScore = 0;
    }

    function emitSeasonStatusChanged(SeasonStatus status) internal {
        emit SeasonStatusChanged(status, block.timestamp);
    }
}