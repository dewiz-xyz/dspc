# Direct Stability Parameters Change Module (DSPC)

A module for MakerDAO that enables direct changes to stability parameters (duty, dsr, ssr) through a simple, secure interface with proper constraints and timelocks.

## Overview

The DSPC module provides a streamlined way to modify stability parameters in the Maker Protocol, including:
- Stability fees (duty) for different collateral types via the Jug contract
- Dai Savings Rate (DSR) via the Pot contract
- Staked Dai Savings Rate (SSR) via the sUSD contract

## Features

- Batch updates for multiple rate changes
- Two-level access control:
  - Admins can configure the module
  - Facilitators can propose and execute rate changes
- Rate change constraints:
  - Min/max caps per rate
  - Max update delta
- Event emission for all actions
- Simple, auditable implementation

## Installation

```bash
forge install
```

## Testing

```bash
forge test
```

## Usage

1. Deploy the contract with the required addresses:
```solidity
DSPC dspc = new DSPC(
    jugAddress,  // For stability fees
    potAddress,  // For DSR
    susdsAddress, // For SSR
    convAddress  // For rate conversions
);
```

2. Configure the module parameters:
```solidity
// Set timelock duration
dspc.file("tau", 1 days);

// Configure constraints for a collateral type
dspc.file("ETH-A", "min", 1);     // Min rate: 0.01%
dspc.file("ETH-A", "max", 1000);  // Max rate: 10%

// Configure constraints for DSR
dspc.file("DSR", "min", 1);    // Min rate: 0.01%
dspc.file("DSR", "max", 800);  // Max rate: 8%
```

3. Add facilitators who can propose and execute rate changes:
```solidity
dspc.kiss(facilitatorAddress);
```

4. Execute a batch of rate changes:
```solidity
DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](2);
updates[0] = DSPC.ParamChange("ETH-A", 150);  // Set ETH-A rate to 1.5%
updates[1] = DSPC.ParamChange("DSR", 75);     // Set DSR to 0.75%
dspc.set(updates);
```

## Security

The module implements a robust security model:
- Two-level access control (admins and facilitators)
- Rate constraints to prevent extreme changes
- Disabling without GSM delay via DSPCMom contract
- Circuit breaker (halt) functionality
- All actions emit events for transparency

## License

AGPL-3.0-or-later
