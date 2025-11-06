# Clanker token address predictor

Utilities and tests for predicting the CREATE2 deployment address of Clanker tokens. Given a `TokenConfig`, we reproduce the factory’s CREATE2 parameters (creation code, constructor args, salt) and derive the token address before deployment. The repo contains:

- `src/ClankerAddressPredictor.sol` – library that pulls the factory’s bytecode and hard-coded supply for deterministic predictions.
- `script/PredictAddress.s.sol` – Foundry script that prints the predicted address for a config read from env variables.
- `test/ClankerAddressPredictor.t.sol` – tests that replay the CREATE2 path against the mainnet factory on a fork, including a regression case for a real deployment.

We also check the production Clanker factory's token creation code into `src/ClankerFactoryCreationCode.sol` so the predictor matches the production bytecode exactly.

## Development

This repo uses Foundry for development and testing. To get started:

1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
2. Run `forge install` to fetch dependencies
3. Run `forge build` to compile the contracts
4. Provide a `mainnet` RPC URL in `.env` (used by the tests)
5. Run `FOUNDRY_PROFILE=clanker forge test` to execute the suite

The predictor itself is self-contained and does not require any runtime state beyond the captured creation code and the factory address. The tests spin up a mainnet fork so they can compare our prediction with the actual factory deployment.
