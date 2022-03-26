# QBM ERC721A Token

NFT contract that use ERC721A to significantly reduce the gas consumption.\
You can use this contract to create your NFT Collection just by updating some values\
>_(I will explain how to do it below)_ 

## Using this contract to deploy your own NFT Collection

Follow this steps to deploy your own instance of this contract.

### Adapting the Contract and Environment

1. **Update the contract _(`contracts/QBM.sol`)_**:
    - Update this file name to your collection name.
    - Update this contract name _(`QBM.sol: line 11`)_ to the name of your collection
    - Set the constants values to fit your needs _(`QBM.sol: line 13 to line 18`)_
    - Set the base URIs _(`QBM.sol: line 24 to line 25`)_
    - Update all the `require` messages in the file _(change QBM to your contract name.)_
2. **Update the deploy script _(`scripts/deploy.py`)_**:
    - Update the import, change `QBM` to the name of your contract _(`deploy.py: line 2`)_
    - Update the contract to deploy in the `deploy_contract` function _(`deploy.py line 8`)_ 
3. **Update the `.env` file _(`.env`)_**
    - Set the whitelist sale start date in the format `yyyy-mm-dd` _(`WHITELIST_SALE_START`)_
    - Set the public sale start date in the format `yyyy-mm-dd`_(`PUBLIC_SALE_START`)_
    - Set the private key of the deployer account _(`PRIVATE_KEY`)_
    - Set your project's infura project ID _(`WEB3_INFURA_PROJECT_ID`)_
    - Set the deployer etherscan API Key _(`ETHERSCAN_TOKEN`)_

### Installing Brownie and its Dependencies

1. Create a python virtual environment by running the following command: `python3 -m venv venv`
2. Activate the virtual env by running: `source venv/bin/activate`
3. Install all this project's dependencies with the following command: `pip install -r requirements.txt`

### Testing and Deploying the Contract

1. Execute the tests using the command: `brownie test`
2. Deploy locally using the command: `brownie run scripts/deploy.py`
3. Deploy on Rinkeby using the command: `brownie run scripts/deploy.py --network rinkeby`
3. Deploy on Mainnet using the command: `brownie run scripts/deploy.py --network mainnet`

## License

This project is licensed under the [MIT license](LICENSE).