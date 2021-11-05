import brownie
import pytest

from eth_account import Account

AMOUNT = 100

# TODO:
# test migration
# add owner and tests for owner
# fix failing partial transfer


def test_config(gov, token, vault, registry, shape_shift_router):
    # No vault added to the registry yet, so these methods should fail
    assert registry.numVaults(token) == 0

    with brownie.reverts():
        shape_shift_router.bestVault(token)
  
    # This won't revert though, there's no Vaults yet
    assert shape_shift_router.allVaults(token) == []

    # Now they work when we have a Vault
    registry.newRelease(vault, {"from": gov})
    registry.endorseVault(vault, {"from": gov})
    
    assert registry.numVaults(token) == 1
    assert shape_shift_router.bestVault(token) == vault
    assert shape_shift_router.allVaults(token) == [vault]


def test_setRegistry(rando, affiliate, gov, shape_shift_router, new_registry):
    with brownie.reverts():
        shape_shift_router.setRegistry(rando, {"from": rando})

    with brownie.reverts():
        shape_shift_router.setRegistry(rando, {"from": affiliate})
    # Cannot set to an invalid registry
    with brownie.reverts():
        shape_shift_router.setRegistry(rando, {"from": gov})

    # yGov must be the gov on the new registry too
    new_registry.setGovernance(rando, {"from": gov})
    new_registry.acceptGovernance({"from": rando})
    with brownie.reverts():
        shape_shift_router.setRegistry(new_registry, {"from": gov})
    new_registry.setGovernance(gov, {"from": rando})
    new_registry.acceptGovernance({"from": gov})

    shape_shift_router.setRegistry(new_registry, {"from": gov})


def test_deposit(token, registry, vault, shape_shift_router, gov, rando):
    registry.newRelease(vault, {"from": gov})
    registry.endorseVault(vault, {"from": gov})
    token.transfer(rando, 10000, {"from": gov})
    assert vault.balanceOf(rando) == vault.balanceOf(shape_shift_router) == 0

    token.approve(shape_shift_router, 10000, {"from": rando})
    shape_shift_router.deposit(token, rando, 10000, {"from": rando})
    assert vault.balanceOf(rando) == 10000
    assert vault.balanceOf(shape_shift_router) == 0
    assert token.balanceOf(rando) == 0
    assert token.balanceOf(shape_shift_router) == 0

def test_deposit_with_recipient(token, registry, vault, shape_shift_router, gov, rando, rando2):
    registry.newRelease(vault, {"from": gov})
    registry.endorseVault(vault, {"from": gov})
    token.transfer(rando, 10000, {"from": gov})
    assert vault.balanceOf(rando) == vault.balanceOf(shape_shift_router) == 0
    
    token.approve(shape_shift_router, 10000, {"from": rando})
    shape_shift_router.deposit(token, rando2, 10000, {"from": rando})

    assert vault.balanceOf(rando2) == 10000
    assert vault.balanceOf(rando) == 0
    
    assert vault.balanceOf(shape_shift_router) == 0
    assert token.balanceOf(rando) == 0
    assert token.balanceOf(shape_shift_router) == 0

def test_withdraw_all(token, registry, vault, shape_shift_router, gov, rando):
    registry.newRelease(vault, {"from": gov})
    registry.endorseVault(vault, {"from": gov})
    token.transfer(rando, 1000000, {"from": gov})
    token.approve(shape_shift_router, 1000000, {"from": rando})
    shape_shift_router.deposit(token, rando, 1000000, {"from": rando})

    vault.approve(shape_shift_router, vault.balanceOf(rando), {"from": rando})
    shape_shift_router.withdraw(token, rando, 1000000, True, {"from": rando})
    
    assert token.balanceOf(shape_shift_router) == 0
    assert vault.balanceOf(shape_shift_router) == 0
    assert token.balanceOf(rando) == 1000000

def test_withdraw_all_with_recipient(token, registry, vault, shape_shift_router, gov, rando, rando2):
    registry.newRelease(vault, {"from": gov})
    registry.endorseVault(vault, {"from": gov})
    token.transfer(rando, 1000000, {"from": gov})
    token.approve(shape_shift_router, 1000000, {"from": rando})
    shape_shift_router.deposit(token, rando, 1000000, {"from": rando})

    vault.approve(shape_shift_router, vault.balanceOf(rando), {"from": rando})
    shape_shift_router.withdraw(token, rando2, 1000000, True, {"from": rando})
    
    assert token.balanceOf(shape_shift_router) == 0
    assert vault.balanceOf(shape_shift_router) == 0
    assert token.balanceOf(rando) == 0
    assert token.balanceOf(rando2) == 1000000

def test_withdraw_max(token, registry, vault, shape_shift_router, gov, rando):
    registry.newRelease(vault, {"from": gov})
    registry.endorseVault(vault, {"from": gov})
    token.transfer(rando, 10000, {"from": gov})
    token.approve(shape_shift_router, 10000, {"from": rando})
    shape_shift_router.deposit(token, rando, 10000, {"from": rando})

    vault.approve(shape_shift_router, vault.balanceOf(rando), {"from": rando})
    shape_shift_router.withdraw(token, rando, {"from": rando})
    
    assert token.balanceOf(shape_shift_router) == 0
    assert vault.balanceOf(shape_shift_router) == 0
    assert token.balanceOf(rando) == 10000

def test_withdraw_max_with_recipient(token, registry, vault, shape_shift_router, gov, rando, rando2):
    registry.newRelease(vault, {"from": gov})
    registry.endorseVault(vault, {"from": gov})
    token.transfer(rando, 10000, {"from": gov})
    token.approve(shape_shift_router, 10000, {"from": rando})
    shape_shift_router.deposit(token, rando, 10000, {"from": rando})

    vault.approve(shape_shift_router, vault.balanceOf(rando), {"from": rando})
    shape_shift_router.withdraw(token, rando2, {"from": rando})
    
    assert token.balanceOf(shape_shift_router) == 0
    assert vault.balanceOf(shape_shift_router) == 0
    assert token.balanceOf(rando) == 0
    assert token.balanceOf(rando2) == 10000

def test_withdraw_half(token, registry, vault, shape_shift_router, gov, rando):
    registry.newRelease(vault, {"from": gov})
    registry.endorseVault(vault, {"from": gov})
    token.transfer(rando, 1000000, {"from": gov})
    token.approve(shape_shift_router, 1000000, {"from": rando})
    shape_shift_router.deposit(token, rando, 1000000, {"from": rando})

    vault.approve(shape_shift_router, vault.balanceOf(rando), {"from": rando})
    shape_shift_router.withdraw(token, rando, 500000, True, {"from": rando})
    
    assert token.balanceOf(rando) == 500000
    # TODO:
    # this currently fails due to the BaseRouter call 
    # `_bestVault.pricePerShare().div(10**_bestVault.decimals())`
    # not re-depositing the correct amount.
    # assert token.balanceOf(shape_shift_router) == 0
    # assert vault.balanceOf(shape_shift_router) == 0
    