# Network 1 (Ethereum Mainnet) Deployment Configuration

This directory contains the configuration files for deploying DSPC on Ethereum Mainnet.

## Files

### dspc-deploy.json
Configuration for deploying DSPC and DSPCMom contracts:
- `conv`: Address of the converter contract that handles rate conversions between basis points and ray format

## Usage

1. Copy `template-dspc-deploy.json` into a new file (i.e.: `dspc-deploy.json`)
2. Edit the new file with the correct `conv` address
3. Run the deployment script:
```bash
FOUNDRY_SCRIPT_CONFIG=dspc-deploy forge script script/DSPCDeploy.s.sol:DSPCDeployScript \
    --rpc-url $ETH_RPC_URL \
    --broadcast

The deployment script will:
1. Load system addresses from chainlog (jug, pot, susds)
2. Deploy DSPC and DSPCMom contracts
4. Export addresses to `/script/output/1/dspc-deploy.json`
