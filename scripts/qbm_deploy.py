from datetime import datetime
from brownie import QBM

from .helpers import get_account, get_config


def deploy_qbm():
    account = get_account()
    config = get_config()
    if not config:
        print("No configuration defined for this network.")
        return
    whitelist_sale_start = datetime.fromisoformat(config.get("whitelist_sale_start"))
    public_sale_start = datetime.fromisoformat(config.get("public_sale_start"))
    qbm = QBM.deploy(
        config.get("proxy_address"),
        int(whitelist_sale_start.timestamp()),
        int(public_sale_start.timestamp()),
        {"from": account},
        publish_source=config.get("verify"),
    )
    print("Contract deployed at:", qbm.address)
    return qbm


def main():
    deploy_qbm()
