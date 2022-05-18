from brownie import accounts, StakingLocked, exceptions, Wei, chain
import brownie
import pytest

@pytest.fixture
def stakingLocked():
    stakingLocked = StakingLocked.deploy({"from": accounts[0]})
    tx = stakingLocked.stake({"from": accounts[0], "amount": Wei("1 ether")})

    return stakingLocked

def test_unstake(stakingLocked):
    assert stakingLocked.seeBalance({"from": accounts[0]}) == Wei("1 ether")
    stakingLocked.unstake(Wei("1 ether"), {"from": accounts[0]})
    assert stakingLocked.seeBalance({"from": accounts[0]}) == 0

    assert accounts[0].balance() == Wei("100 ether")

def test_unstake_too_much(stakingLocked):
    with brownie.reverts():
        stakingLocked.unstake(Wei("2 ether"), {"from": accounts[0]})

def test_unstake_locked(stakingLocked):
    stakingLocked.stakeLocked({"from": accounts[1], "amount": Wei("1 ether")})
    assert stakingLocked.seeBalance({"from": accounts[1]}) == Wei("1 ether")
    chain.mine(503)
    stakingLocked.unstakeLocked(Wei("1 ether"), {"from": accounts[1]})
    assert accounts[1].balance() == Wei("100 ether")
    assert stakingLocked.georgeCoinBalance({"from": accounts[1]}) == Wei ("0.1 ether")

def test_total_balance(stakingLocked):
    stakingLocked.stakeLocked({"from": accounts[0], "amount": Wei("1 ether")})
    assert stakingLocked.seeBalance({"from": accounts[0]}) == Wei("2 ether")

def test_unstake_too_early(stakingLocked):
    stakingLocked.stakeLocked({"from": accounts[0], "amount": Wei("1 ether")})
    chain.mine(100)
    with brownie.reverts():
        stakingLocked.unstakeLocked(Wei("1 ether"), {"from": accounts[0]})

def test_stake_locked_again(stakingLocked):
    stakingLocked.stakeLocked({"from": accounts[0], "amount": Wei("1 ether")})
    chain.mine(251)
    stakingLocked.stakeLocked({"from": accounts[0], "amount": Wei("1 ether")})
    assert stakingLocked.georgeCoinBalance({"from": accounts[0]}) == Wei("0.05 ether")

def test_see_locked_reward(stakingLocked):
    stakingLocked.stakeLocked({"from": accounts[0], "amount": Wei("1 ether")})
    chain.mine(252)
    print(stakingLocked.seeLockedReward({"from": accounts[0]}))
    assert stakingLocked.seeLockedReward({"from": accounts[0]}) == Wei("0.05 ether")

def test_reward_reduction(stakingLocked):
    stakingLocked.stakeLocked({"from": accounts[0], "amount": Wei("20 ether")})
    stakingLocked.stakeLocked({"from": accounts[1], "amount": Wei("20 ether")})
    stakingLocked.stakeLocked({"from": accounts[2], "amount": Wei("20 ether")})
    stakingLocked.stakeLocked({"from": accounts[3], "amount": Wei("20 ether")})
    stakingLocked.stakeLocked({"from": accounts[4], "amount": Wei("20 ether")})
    stakingLocked.stakeLocked({"from": accounts[5], "amount": Wei("20 ether")})

    chain.mine(498)
    stakingLocked.unstakeLocked(Wei("20 ether"), {"from": accounts[0]})
    stakingLocked.unstakeLocked(Wei("20 ether"), {"from": accounts[1]})
    stakingLocked.unstakeLocked(Wei("20 ether"), {"from": accounts[2]})
    stakingLocked.unstakeLocked(Wei("20 ether"), {"from": accounts[3]})
    stakingLocked.unstakeLocked(Wei("20 ether"), {"from": accounts[4]})
    stakingLocked.unstakeLocked(Wei("20 ether"), {"from": accounts[5]})

    assert stakingLocked.georgeCoinBalance({"from": accounts[0]}) == Wei ("2 ether")
    # If five accounts claim a reward of 2 ether each, the sixth account should only get half this reward
    assert stakingLocked.georgeCoinBalance({"from": accounts[5]}) == Wei ("1 ether")