import brownie
import pytest
from web3 import Web3

from scripts.qbm_deploy import deploy_qbm
from scripts import helpers


# ------Fixtures------


@pytest.fixture
def account():
    yield helpers.get_account()


@pytest.fixture
def contract():
    yield deploy_qbm()


@pytest.fixture(scope="function")
def start_whitelist_sale(contract, chain):
    chain.snapshot()
    chain.sleep(contract.whitelistSaleStartTime() - chain.time())
    yield
    chain.revert()


@pytest.fixture(scope="function")
def start_public_sale(contract, chain):
    chain.snapshot()
    chain.sleep(contract.publicSaleStartTime() - chain.time())
    yield
    chain.revert()


# ------Test-Base-Values------


def test_supplies(contract):
    # Assert
    assert contract.MAX_SUPPLY() == 40
    assert contract.MAX_PER_USER() == 5
    assert contract.SUPPLY_FOR_DEVS() == 15


def test_prices(contract):
    # Assert
    assert contract.PUBLIC_PRICE() == Web3.toWei(0.069, "ether")
    assert contract.WHITELIST_PRICE() == Web3.toWei(0.025, "ether")


# ------Test-Whitelist-Creation------


def test_seed_whitelist(contract, accounts):
    # Act
    contract.seedWhitelist([accounts[0], accounts[1], accounts[2]], [1, 1, 2])
    # Assert
    assert contract.whitelist(accounts[0]) == 1
    assert contract.whitelist(accounts[1]) == 1
    assert contract.whitelist(accounts[2]) == 2


def test_seed_whitelist_empty(contract):
    # Act/Assert
    with brownie.reverts("QBM: No accounts provided."):
        contract.seedWhitelist([], [])


def test_seed_whitelist_accounts_and_amounts_not_matching(contract, accounts):
    # Act/Assert
    with brownie.reverts("QBM: Amounts and accounts don't match."):
        contract.seedWhitelist([accounts[0], accounts[1]], [1, 2, 3])


# ------Test-Whitelist-Mint------


def test_whitelist_mint(contract, account, start_whitelist_sale):
    # Arrange
    contract.seedWhitelist([account], [1])
    # Act (send some extra eth to test the refund)
    contract.whitelistMint({"from": account, "value": Web3.toWei(0.5, "ether")})
    # Assert
    assert contract.balance() == contract.WHITELIST_PRICE()
    assert contract.balanceOf(account) == 1


def test_whitelist_mint_before_starts(contract, account):
    # Arrange
    contract.seedWhitelist([account], [1])
    # Act/Assert
    with brownie.reverts("QBM: Whitelist sale has not started yet."):
        contract.whitelistMint({"from": account, "value": Web3.toWei(0.5, "ether")})


def test_whitelist_mint_with_no_reservation(contract, account, start_whitelist_sale):
    # Act/Assert
    with brownie.reverts("QBM: User has no mints reserved."):
        contract.whitelistMint({"from": account, "value": Web3.toWei(0.5, "ether")})


def test_whitelist_mint_more_than_permited(contract, account, start_whitelist_sale):
    # Arrange
    contract.seedWhitelist([account], [6])
    for _ in range(5):
        contract.whitelistMint({"from": account, "value": Web3.toWei(5, "ether")})
    # Act/Assert
    with brownie.reverts("QBM: Exceeds the max amount per user."):
        contract.whitelistMint({"from": account, "value": Web3.toWei(5, "ether")})

    assert contract.balanceOf(account) == 5
    assert contract.balance() == contract.WHITELIST_PRICE() * 5


def test_whitelist_mint_withou_enough_eth(contract, account, start_whitelist_sale):
    # Act/Assert
    with brownie.reverts("QBM: Not enough ETH."):
        contract.whitelistMint({"from": account, "value": Web3.toWei(0.01, "ether")})


# ------Test-Public-Mint------


def test_public_mint(contract, account, start_public_sale):
    # Act (send some extra eth to test the refund)
    contract.publicMint(1, {"from": account, "value": Web3.toWei(5, "ether")})
    # Assert
    assert contract.balance() == contract.PUBLIC_PRICE()
    assert contract.balanceOf(account) == 1


def test_public_mint_before_starts(contract, accounts):
    # Act/Assert
    with brownie.reverts("QBM: Public sale has not started yet."):
        contract.publicMint(1, {"from": accounts[0], "value": Web3.toWei(5, "ether")})


def test_public_mint_without_enough_eth(contract, account, start_public_sale):
    # Act/Assert
    with brownie.reverts("QBM: Not enough ETH."):
        contract.publicMint(1, {"from": account, "value": Web3.toWei(0.01, "ether")})


def test_public_mint_more_than_permited(contract, account, start_public_sale):
    # Act/Assert
    with brownie.reverts("QBM: Exceeds the max amount per user."):
        contract.publicMint(6, {"from": account, "value": Web3.toWei(6, "ether")})
    assert contract.balanceOf(account) == 0
    # Now with one correctly minted NFT trying to mint 5 more.
    contract.publicMint(1, {"from": account, "value": Web3.toWei(6, "ether")})
    with brownie.reverts("QBM: Exceeds the max amount per user."):
        contract.publicMint(5, {"from": account, "value": Web3.toWei(6, "ether")})
    # Assert Balances
    assert contract.balanceOf(account) == 1
    assert contract.balance() == contract.PUBLIC_PRICE()


def test_public_mint_all_the_nfts(contract, accounts, start_public_sale):
    # Arrange
    five_mints_price = contract.PUBLIC_PRICE() * 5
    # Act/Assert
    for index in range(int(contract.MAX_SUPPLY() / 5)):
        contract.publicMint(5, {"from": accounts[index], "value": five_mints_price})
        assert contract.balanceOf(accounts[index]) == 5
    with brownie.reverts("QBM: Exceeds the max supply."):
        contract.publicMint(5, {"from": accounts[-1], "value": five_mints_price})
    assert contract.balance() == contract.PUBLIC_PRICE() * contract.MAX_SUPPLY()


def test_public_mint_five(contract, account, start_public_sale):
    # Act
    contract.publicMint(5, {"from": account, "value": Web3.toWei(5, "ether")})
    # Assert
    assert contract.balanceOf(account) == 5
    assert contract.balance() == contract.PUBLIC_PRICE() * 5

# ------Test-Dev-Mint------

def test_dev_mint(contract, accounts):
    # Act (send some extra eth to test the refund)
    contract.devMint(accounts[1], 1, {"from": accounts[0]})
    # Assert
    assert contract.balanceOf(accounts[1]) == 1

def test_dev_mint_five(contract, accounts):
    # Act
    contract.devMint(accounts[1], 5, {"from": accounts[0]})
    # Assert
    assert contract.balanceOf(accounts[1]) == 5

def test_dev_mint_all_reserved(contract, accounts):
    # Act
    contract.devMint(accounts[1], contract.SUPPLY_FOR_DEVS(), {"from": accounts[0]})
    # Assert
    with brownie.reverts("QBM: Exceeds the mints reserved for devs."):
        contract.devMint(accounts[1], 1, {"from": accounts[0]})
    assert contract.balanceOf(accounts[1]) == contract.SUPPLY_FOR_DEVS()
