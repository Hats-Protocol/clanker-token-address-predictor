// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";
import { ClankerAddressPredictor } from "../src/ClankerAddressPredictor.sol";
import { IClanker } from "lib/v4-contracts/src/interfaces/IClanker.sol";

/// @title PredictAddress
/// @notice Script to predict ClankerToken deployment address from environment variables
contract PredictAddress is Script {
  uint256 constant TOKEN_SUPPLY = 100_000_000_000e18; // 100 billion tokens

  // Factory addresses by chain ID
  address constant ETHEREUM_FACTORY = 0x6C8599779B03B00AAaE63C6378830919Abb75473;
  address constant BASE_FACTORY = 0xE85A59c628F7d27878ACeB4bf3b35733630083a9;

  string public constant CLANKER_WORLD_CONTEXT = '{"interface":"clanker.world","platform":"","messageId":"","id":""}';

  function predict(IClanker.TokenConfig memory config) public view returns (address predicted) {
    // Get factory address for current chain
    address factory = getFactoryAddress(block.chainid);

    // Predict token address
    predicted = ClankerAddressPredictor.predictTokenAddress(factory, config);

    // Output results
    console2.log("=== Clanker Token Address Prediction ===");
    console2.log("");
    console2.log("Network Chain ID:", block.chainid);
    console2.log("Factory Address:", factory);
    console2.log("");
    console2.log("Token Configuration:");
    console2.log("  Admin:", config.tokenAdmin);
    console2.log("  Name:", config.name);
    console2.log("  Symbol:", config.symbol);
    console2.log("  Salt:", vm.toString(config.salt));
    console2.log("  Image:", config.image);
    console2.log("  Metadata:", config.metadata);
    console2.log("  Context:", config.context);
    console2.log("  Supply:", TOKEN_SUPPLY);
    console2.log("  Originating Chain ID:", config.originatingChainId);
    console2.log("");
    console2.log("Predicted Token Address:", predicted);
    console2.log("");
    console2.log("========================================");
  }

  function run() public view {
    // Load token configuration from environment variables
    IClanker.TokenConfig memory config = IClanker.TokenConfig({
      tokenAdmin: vm.envAddress("TOKEN_ADMIN"),
      name: vm.envString("TOKEN_NAME"),
      symbol: vm.envString("TOKEN_SYMBOL"),
      salt: vm.envBytes32("TOKEN_SALT"),
      image: vm.envString("TOKEN_IMAGE"),
      metadata: vm.envString("TOKEN_METADATA"),
      context: CLANKER_WORLD_CONTEXT,
      originatingChainId: block.chainid // Derived from runtime network
    });

    // Predict token address
    predict(config);
  }

  /// @notice Get factory address for a given chain ID
  /// @param chainId The chain ID to lookup
  /// @return factory The factory address for the chain
  function getFactoryAddress(uint256 chainId) internal pure returns (address factory) {
    if (chainId == 1) {
      // Ethereum mainnet
      return ETHEREUM_FACTORY;
    } else if (chainId == 8453) {
      // Base mainnet
      return BASE_FACTORY;
    } else {
      // For other chains, revert with helpful message
      revert(string.concat("No factory address configured for chain ID: ", vm.toString(chainId)));
    }
  }
}
