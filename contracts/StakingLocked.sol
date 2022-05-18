// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.6.0/contracts/token/ERC20/ERC20.sol";

/**
 * @title StakingLocked
 * @dev Stake and earn rewrads
 */
contract StakingLocked is ERC20("GeorgeCoin", "GEC"){
    enum RewardPhase {SeedPhase, EarlyAdopter, EarlyMass, MainPhase}

    struct Staker {
        uint256 time;
        uint256 balance;
    }

    mapping (address => Staker) stakers;
    mapping (address => Staker) lockedStakers;
    RewardPhase phase;
    // 88200 for production, 500 for test
    uint32 lockTime = 88200;
    uint256 circSupply = 0;
    // 1.000.000 for production, 10 for test
    uint256 supplyTreshold = 1000000 * 1000000000000000000;

    constructor() {
        phase = RewardPhase.SeedPhase;
    }

    function seeBalance() public view returns(uint256) {
        return stakers[msg.sender].balance + lockedStakers[msg.sender].balance;
    }

    function stake() public payable {
        if (stakers[msg.sender].time > 0 && stakers[msg.sender].time < block.number) {
            claimReward();
        }
        stakers[msg.sender].time = block.number;
        stakers[msg.sender].balance += msg.value;
    }

    function stakeLocked() public payable {
        if (lockedStakers[msg.sender].time > 0 && lockedStakers[msg.sender].time < block.number) {
            _rewardLockedReset();
        }
        lockedStakers[msg.sender].time = block.number;
        lockedStakers[msg.sender].balance += msg.value;
    }

    function unstake(uint256 amount) public {
        require(amount <= stakers[msg.sender].balance, "Withdraw amount higher than balance");
        claimReward();
        unchecked {
            stakers[msg.sender].balance -= amount;
            stakers[msg.sender].time = 0;
        }
        payable(msg.sender).transfer(amount);
    }

    function unstakeLocked(uint256 amount) public {
        // Lockup time is two weeks, using 6300 blocks per day
        require(amount <= lockedStakers[msg.sender].balance, "Withdraw amount higher than balance");
        require(lockedStakers[msg.sender].time + lockTime <= block.number, "Withdraw only possible after two weeks");
        claimRewardLocked();
        unchecked {
            lockedStakers[msg.sender].balance -= amount;
            lockedStakers[msg.sender].time = 0;
        }
        payable(msg.sender).transfer(amount);
    }

    function seeReward() public view returns(uint256) {
        if(stakers[msg.sender].time > 0) {
            return calcReward();
        }
        return 0;
    }

    function seeLockedReward() public view returns(uint256) {
        if(lockedStakers[msg.sender].time > 0) {
            return calcRewardLocked();
        }
        return 0;
    }

    function claimReward() public {
        require(stakers[msg.sender].time > 0, "You have nothing staked");
        uint256 reward = calcReward();
        mintReward(reward);
        stakers[msg.sender].time = block.number;
        _transfer(address(this), msg.sender, reward);
    }

    function claimRewardLocked() public {
        require(lockedStakers[msg.sender].time > 0, "You have nothing staked");
        require(lockedStakers[msg.sender].time <= block.number - lockTime, "Rewards available after two weeks");
        // 25% reward increase (6300 / 1.25)
        uint256 reward = calcRewardLocked();
        mintReward(reward);
        lockedStakers[msg.sender].time = block.number;
        _transfer(address(this), msg.sender, reward);
    }

    function georgeCoinBalance() public view returns (uint256) {
        return balanceOf(msg.sender);
    }

    // This function is used when a user stacks more money into the locked vault.
    // Since this should be able to happen before the lookup period is over,
    // this internal function sends the reward before the period is over.
    function _rewardLockedReset() internal {
        uint256 reward = calcRewardLocked();
        mintReward(reward);
        lockedStakers[msg.sender].time = block.number;
        _transfer(address(this), msg.sender, reward);
    }

    function calcReward() internal view returns(uint256) {
        return (block.number - stakers[msg.sender].time) * stakers[msg.sender].balance / 6300 / (uint(phase) + 1);
    }

    function calcRewardLocked() internal view returns(uint256) {
        return (block.number - lockedStakers[msg.sender].time) * lockedStakers[msg.sender].balance / 5040 / (uint(phase) + 1);
    }

    function mintReward(uint256 amount) internal {
        circSupply += amount;
        _mint(address(this), amount);
        if (circSupply < supplyTreshold) {
            phase = RewardPhase.SeedPhase;
        }
        else if (circSupply < supplyTreshold * 5) {
            phase = RewardPhase.EarlyAdopter;
        }
        else if (circSupply < supplyTreshold * 20) {
            phase = RewardPhase.EarlyMass;
        }
        else {
            phase = RewardPhase.MainPhase;
        }
    }
}