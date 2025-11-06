// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

/**
 * @title ClankerMainnetTestBase
 * @notice Base test contract with mainnet addresses and common test infrastructure
 * @dev All tests that interact with mainnet deployments should extend this contract
 */
abstract contract ClankerMainnetTestBase is Test {
  // ============ Mainnet Uniswap V4 Infrastructure ============

  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address constant PERMIT_2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
  address constant POSITION_MANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
  address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
  address constant UNIVERSAL_ROUTER = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;

  // ============ Mainnet Clanker Addresses ============

  address constant CLANKER = 0x6C8599779B03B00AAaE63C6378830919Abb75473;
  address constant CLANKER_FEE_LOCKER = 0xA9C0a423f0092176fC48d7B50a1fCae8cf5BB441;
  address constant CLANKER_VAULT = 0xa1da0600Eb4A9F3D4a892feAa2c2caf80A4A2f14;
  address constant CLANKER_AIRDROP_V2 = 0x303470b6b6a35B06A5A05763A7caD776fbf27B71;
  address constant CLANKER_DEV_BUY = 0x70aDdc06fE89a5cF9E533aea8D025dB06795e492;
  address constant CLANKER_MEV_FEE_DECAY = 0x33e2Eda238edcF470309b8c6D228986A1204c8f9;
  address constant CLANKER_LP_LOCKER_FEE_CONVERSION = 0x00C4b21889145CF0D99f2e05919103e0c3991974;
  address constant CLANKER_STATIC_HOOK_V2 = 0x6C24D0bCC264EF6A740754A11cA579b9d225e8Cc;
  address constant CLANKER_POOL_EXTENSION_ALLOWLIST = 0xA25e594869ddb46c33233A793E3c8b207CC719a2;
  address constant CLANKER_PRESALE_ETH_TO_CREATOR = 0xf7db81910444ab0f07bA264d7636d219A8c7769D;
  address constant CLANKER_PRESALE_ALLOWLIST = 0xF6C7Ff92F71e2eDd19c421E4962949Df4cD6b6F3;

  // ============ Fork Configuration ============

  /// @notice Block number to fork from - should be recent mainnet block
  uint256 constant FORK_BLOCK = 23_719_377;

  /// @notice URL for mainnet RPC - set via QUICKNODE_MAINNET_RPC env variable
  string constant FORK_RPC_URL = "mainnet";

  // ============ Test Setup ============

  /// @notice Setup function - creates mainnet fork at specified block
  function setUp() public virtual {
    // Create and select mainnet fork
    vm.createSelectFork(FORK_RPC_URL, FORK_BLOCK);

    // Verify we're on the correct chain
    require(block.chainid == 1, "Must be on Ethereum mainnet");
  }

  // ============ Helper Functions ============

  /// @notice Get current block number for logging
  function currentBlock() internal view returns (uint256) {
    return block.number;
  }

  /// @notice Get current timestamp for logging
  function currentTimestamp() internal view returns (uint256) {
    return block.timestamp;
  }
}
