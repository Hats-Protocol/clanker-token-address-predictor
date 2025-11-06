// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IClanker } from "lib/v4-contracts/src/interfaces/IClanker.sol";
import { ClankerTokenCreationCode } from "./ClankerTokenCreationCode.sol";

/// @title ClankerAddressPredictor
/// @notice Library for predicting ClankerToken deployment addresses using CREATE2
/// @dev Uses CREATE2 formula: keccak256(0xff ++ deployer ++ salt ++ initCodeHash)[12:]
library ClankerAddressPredictor {
  /// @notice Exact creation bytecode the mainnet factory embeds for ClankerToken deployments
  /// @dev Sourced from src/ClankerFactoryCreationCode.sol (generated from CreationCodeOnly.txt)
  bytes internal constant TOKEN_CREATION_CODE = ClankerTokenCreationCode.CODE;
  uint256 internal constant FACTORY_SUPPLY = 100_000_000_000e18;

  /// @notice Predicts the address of a Clanker token deployed via the factory
  /// @param deployer The factory address executing the CREATE2 deployment
  /// @param tokenConfig Struct matching the factory deployment parameters
  /// @return predicted The predicted token contract address
  function predictTokenAddress(address deployer, IClanker.TokenConfig memory tokenConfig)
    internal
    pure
    returns (address predicted)
  {
    // Factory salts the deployment with keccak(admin, salt)
    bytes32 salt = keccak256(abi.encode(tokenConfig.tokenAdmin, tokenConfig.salt));

    // Constructor args must exactly match ClankerDeployer.deployToken
    bytes memory constructorArgs = abi.encode(
      tokenConfig.name,
      tokenConfig.symbol,
      FACTORY_SUPPLY,
      tokenConfig.tokenAdmin,
      tokenConfig.image,
      tokenConfig.metadata,
      tokenConfig.context,
      tokenConfig.originatingChainId
    );

    // Use the embedded token creation code captured from mainnet factory
    bytes32 initCodeHash = keccak256(abi.encodePacked(TOKEN_CREATION_CODE, constructorArgs));

    // Standard CREATE2 formula
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash));

    predicted = address(uint160(uint256(hash)));
  }
}
