from brownie import accounts, network, config

FORKED_ENVS = ["mainnet-fork", "mainnet-fork-dev"]
LOCAL_ENVS = ["development", "ganache-local"]


def get_account(index: int = None, id: int = None):
    if index:
        return accounts[index]
    if id:  # id of an account created manually in brownie
        return accounts.load(id)
    if network.show_active() in (FORKED_ENVS and LOCAL_ENVS):
        return accounts[0]
    return accounts.add(config["wallets"]["from_key"])


def get_config() -> dict:
    if not network.show_active() in config["networks"]:
        return False
    return config["networks"][network.show_active()]
