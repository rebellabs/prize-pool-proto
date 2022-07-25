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
    SeasonStatus private _seasonStatus;

    address private _trustedSigner;

    address private _rewardsToken;

    uint256 private _totalUsersScore;
    uint256 private _prizePool = 1 ether;
    uint256 private _claimPeriod = 3 days;
    uint256 private _seasonStartDate;
    uint256 private _seasonFinishDate;
    uint256 private _seasonDuration = 30 days;

    mapping(address => uint256) private _nonces;
    mapping(bytes => bool) private _executed;
    EnumerableMap.AddressToUintMap private _scores;

    event SeasonScheduled(uint256 startDate, uint256 duration, uint256 _prizePool);
    event SeasonStatusChanged(SeasonStatus status, uint256 ts);
    event UserRewardClaimed(address user, uint256 amount);

    modifier onlySeasonStatus(SeasonStatus status) {
        require(_seasonStatus == status);
        _;
    }

    constructor(address _signer) Ownable() {
        _trustedSigner = _signer;
    }

    /**
     * @notice Schedule a season to start at a timestamp in the future
     */
    function scheduleSeason(uint256 startDate, uint256 seasonDuration, uint256 prizePool) external
    onlyOwner
    {
        _seasonStartDate = _seasonStartDate;
        _seasonFinishDate = _seasonStartDate + _seasonDuration;
        _prizePool = prizePool;
        _seasonStatus = SeasonStatus.Scheduled;
        _seasonDuration = _seasonDuration;

        emit SeasonScheduled(startDate, seasonDuration, prizePool);
    }

    /**
     * @notice Activate season from scheduled state (Claim -> Active)
     */
    function startSeason() external
    onlyOwner
    onlySeasonStatus(SeasonStatus.Scheduled)
    {
        _seasonStatus = SeasonStatus.Active;

        emitSeasonStatusChanged(_seasonStatus);
    }

    /**
     * @notice Stop season if it's needed
     */
    function stopSeason() external onlyOwner {
        _seasonStatus = SeasonStatus.Inactive;
        resetSeason();

        emitSeasonStatusChanged(_seasonStatus);
    }

    /**
     * @notice Stop season if it's needed
     */
    function startClaimPeriod() external onlyOwner {
        _seasonStatus = SeasonStatus.Claim;

        emitSeasonStatusChanged(_seasonStatus);
    }

    function getSeasonStartDate() external view returns (uint256) {
        return _seasonStartDate;
    }

    function getSeasonFinishDate() external view returns (uint256) {
        return _seasonFinishDate;
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

    // /**
    //  * @notice Returns reward for a user
    //  */
    // function getUserReward(address user) public view returns (uint) {
    //     uint userScore = _scores.get(user)
    //     return _scores.get(user) /;
    // }

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