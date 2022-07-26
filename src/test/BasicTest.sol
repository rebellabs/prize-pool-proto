// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "./SharedTestSetup.sol";

contract BasicTest is SharedTestSetup {
    function setUp() public {
        // Schedule season and assert status and variables are correct
        scheduleAndAssertScheduled(block.timestamp + 10000, 20000);
        // Now increment block number and timestamp and start season
        vm.roll(2);
        vm.warp(block.timestamp + 10000 + 20000);
        prizePool.startSeason();
        assertEq(prizePool.getSeasonStatus(), 0);
    }

    function testCanAddScore(uint amount) public {
        address randomBozo = addScoreToRandom(amount);
        uint score = prizePool.getUserScore(randomBozo);
        assertEq(score, amount);
    }

    function testCanClaim(uint amountOne, uint amountTwo) public {
        // Sensible limits for possible user scores
        vm.assume(amountOne < 1000000 && amountOne > 0);
        vm.assume(amountTwo < 1000000 && amountTwo > 0);

        // Add some random scores to two users
        address randomBozoOne = addScoreToRandom(amountOne);
        address randomBozoTwo = addScoreToRandom(amountTwo);
        uint scoreOne = prizePool.getUserScore(randomBozoOne);
        uint scoreTwo = prizePool.getUserScore(randomBozoTwo);
        assertEq(scoreOne, amountOne);
        assertEq(scoreTwo, amountTwo);

        // Open claim period and claim rewards
        prizePool.startClaimPeriod();   
        uint balanceOne = randomBozoOne.balance; // Record initial balances 
        uint balanceTwo = randomBozoTwo.balance;
        vm.prank(randomBozoOne);
        prizePool.claimReward();
        vm.prank(randomBozoTwo);
        prizePool.claimReward();

        uint balanceAfterOne = randomBozoOne.balance; // Record balances after claim
        uint balanceAfterTwo = randomBozoTwo.balance;

        // Calculate expected rewards
        uint expRewardOne = prizePoolSize * (scoreOne / (amountOne + amountTwo));
        uint expRewardTwo = prizePoolSize * (scoreTwo / (amountOne + amountTwo));

        // Assert users received correct rewards
        assertEq(expRewardOne, balanceAfterOne - balanceOne);
        assertEq(expRewardTwo, balanceAfterTwo - balanceTwo);
    }
}
