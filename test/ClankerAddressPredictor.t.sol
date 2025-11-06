// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { ClankerAddressPredictor } from "../src/ClankerAddressPredictor.sol";
import { IClanker } from "lib/v4-contracts/src/interfaces/IClanker.sol";
import { Clanker } from "lib/v4-contracts/src/Clanker.sol";

/// forge-config: default.fuzz.runs = 32
contract ClankerAddressPredictorTest is Test {
  // Ethereum Mainnet addresses
  address constant ETHEREUM_FACTORY = 0x6C8599779B03B00AAaE63C6378830919Abb75473;
  uint256 constant TOKEN_SUPPLY = 100_000_000_000e18;
  uint256 constant FORK_BLOCK = 23_719_377; // Block prior to real deployment tx

  address constant MAINNET_HOOK = 0x6C24D0bCC264EF6A740754A11cA579b9d225e8Cc;
  address constant MAINNET_LOCKER = 0x00C4b21889145CF0D99f2e05919103e0c3991974;
  address constant MAINNET_MEV_MODULE = 0x33e2Eda238edcF470309b8c6D228986A1204c8f9;
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  // Pre-loaded addresses for fuzz testing (avoids excessive RPC calls)
  address[] internal preloadedAddresses;
  Clanker internal factory;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
    factory = Clanker(ETHEREUM_FACTORY);

    // Generate 50 pseudorandom addresses using makeAddr
    for (uint256 i = 0; i < 50; i++) {
      preloadedAddresses.push(makeAddr(string.concat("testAddr", vm.toString(i))));
    }

    // Add zero address as edge case
    preloadedAddresses.push(address(0));
  }

  // ============ Fuzz Tests (Foundation Layer) ============

  /// @notice Fuzz test tokenAdmin parameter
  function testFuzz_predictTokenAddress_tokenAdmin(uint256 adminSeed, bytes32 salt) public {
    address admin = _getPreloadedAddress(adminSeed);

    IClanker.TokenConfig memory config = _createDefaultConfig();
    config.tokenAdmin = admin;
    config.salt = salt;

    // Predict address
    address predicted = ClankerAddressPredictor.predictTokenAddress(ETHEREUM_FACTORY, config);

    // Build full deployment config and deploy actual token
    address actual = _deployTokenWithTokenConfig(config);

    // Verify prediction matches reality
    assertEq(predicted, actual, "Predicted address must match actual deployment");
  }

  /// @notice Fuzz test salt parameter
  function testFuzz_predictTokenAddress_salt(bytes32 salt) public {
    IClanker.TokenConfig memory config = _createDefaultConfig();
    config.salt = salt;

    // Predict address
    address predicted = ClankerAddressPredictor.predictTokenAddress(ETHEREUM_FACTORY, config);

    // Build full deployment config and deploy actual token
    address actual = _deployTokenWithTokenConfig(config);

    // Verify prediction matches reality
    assertEq(predicted, actual, "Predicted address must match actual deployment");
  }

  /// @notice Fuzz test name and symbol parameters
  function testFuzz_predictTokenAddress_nameSymbol(string memory name, string memory symbol) public {
    // Bound string lengths to reasonable values
    vm.assume(bytes(name).length > 0 && bytes(name).length <= 100);
    vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 100);

    IClanker.TokenConfig memory config = _createDefaultConfig();
    config.name = name;
    config.symbol = symbol;

    // Predict address
    address predicted = ClankerAddressPredictor.predictTokenAddress(ETHEREUM_FACTORY, config);

    // Build full deployment config and deploy actual token
    address actual = _deployTokenWithTokenConfig(config);

    // Verify prediction matches reality
    assertEq(predicted, actual, "Predicted address must match actual deployment");
  }

  /// @notice Fuzz test metadata strings
  function testFuzz_predictTokenAddress_metadata(string memory image, string memory metadata, string memory context)
    public
  {
    // Bound string lengths
    vm.assume(bytes(image).length <= 100);
    vm.assume(bytes(metadata).length <= 100);
    vm.assume(bytes(context).length <= 100);

    IClanker.TokenConfig memory config = _createDefaultConfig();
    config.image = image;
    config.metadata = metadata;
    config.context = context;

    // Predict address
    address predicted = ClankerAddressPredictor.predictTokenAddress(ETHEREUM_FACTORY, config);

    // Build full deployment config and deploy actual token
    address actual = _deployTokenWithTokenConfig(config);

    // Verify prediction matches reality
    assertEq(predicted, actual, "Predicted address must match actual deployment");
  }

  /// @notice Fuzz test all parameters together
  function testFuzz_predictTokenAddress_allParams(
    uint256 adminSeed,
    bytes32 salt,
    string memory name,
    string memory symbol,
    string memory image,
    string memory metadata,
    string memory context
  ) public {
    // Apply bounds
    vm.assume(bytes(name).length > 0 && bytes(name).length <= 50);
    vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);
    vm.assume(bytes(image).length <= 100);
    vm.assume(bytes(metadata).length <= 100);
    vm.assume(bytes(context).length <= 100);

    IClanker.TokenConfig memory config = IClanker.TokenConfig({
      tokenAdmin: _getPreloadedAddress(adminSeed),
      name: name,
      symbol: symbol,
      salt: salt,
      image: image,
      metadata: metadata,
      context: context,
      originatingChainId: block.chainid
    });

    // Predict address
    address predicted = ClankerAddressPredictor.predictTokenAddress(ETHEREUM_FACTORY, config);

    // Build full deployment config and deploy actual token
    address actual = _deployTokenWithTokenConfig(config);

    // Verify prediction matches reality
    assertEq(predicted, actual, "Predicted address must match actual deployment");
  }

  // ============ Unit Tests ============

  /// @notice Test basic prediction with standard values
  function test_predictTokenAddress_basic() public {
    testFuzz_predictTokenAddress_allParams(
      0, // first preloaded address
      bytes32(uint256(1)), // salt
      "Test Token",
      "TEST",
      "https://example.com/image.png",
      "metadata",
      "context"
    );
  }

  /// @notice Test prediction against real mainnet deployment
  /// @dev Uses actual config from tx 0x81d270103943d4f41c63caee6321d1654c29176ef24a0b4c109ec969bacb4ada
  function test_predictTokenAddress_realDeployment() public {
    // Real deployment config from tx 0x81d270103943d4f41c63caee6321d1654c29176ef24a0b4c109ec969bacb4ada
    IClanker.TokenConfig memory config = IClanker.TokenConfig({
      tokenAdmin: 0x052DCF6cB9dDD12C3F1350344CF6cE64E61bCd38,
      name: "hullo",
      symbol: "hullo",
      salt: 0x000000000000000000000000000000005e95d213a71de2a3918637b124818091,
      image: "https://turquoise-blank-swallow-685.mypinata.cloud/ipfs/bafkreihbx7xgpkwxahbnetgssr553sgcbt4tkjda3niq5z47w6jzudqjni",
      metadata: '{"description":"No description provided","socialMediaUrls":[],"auditUrls":[]}',
      context: '{"interface":"clanker.world","platform":"","messageId":"","id":""}',
      originatingChainId: 1
    });

    // Expected deployed address from the real tx
    address expectedAddress = 0xd1A89f9B07a5170EDC02CE4019d300e095b11B07;

    // Predict address
    address predicted = ClankerAddressPredictor.predictTokenAddress(ETHEREUM_FACTORY, config);

    console2.log("Predicted:", predicted);
    console2.log("Expected:", expectedAddress);
    console2.log("Salt:", uint256(keccak256(abi.encode(config.tokenAdmin, config.salt))));

    // Verify prediction matches the actual deployed address
    assertEq(predicted, expectedAddress, "Predicted address must match real deployed token");
  }

  /// @notice Test empty strings
  function test_predictTokenAddress_emptyStrings() public {
    testFuzz_predictTokenAddress_metadata("", "", "");
  }

  /// @notice Test zero address admin
  function test_predictTokenAddress_zeroAddressAdmin() public {
    IClanker.TokenConfig memory config = _createDefaultConfig();
    config.tokenAdmin = address(0);

    // Predict address
    address predicted = ClankerAddressPredictor.predictTokenAddress(ETHEREUM_FACTORY, config);

    // Build full deployment config and deploy actual token
    address actual = _deployTokenWithTokenConfig(config);

    // Verify prediction matches reality
    assertEq(predicted, actual, "Predicted address must match actual deployment");
  }

  // ============ Helper Functions ============

  /// @notice Create a default token config for testing
  function _createDefaultConfig() internal pure returns (IClanker.TokenConfig memory) {
    return IClanker.TokenConfig({
      tokenAdmin: address(0x1234),
      name: "Test Token",
      symbol: "TEST",
      salt: bytes32(uint256(1)),
      image: "https://example.com/image.png",
      metadata: "Test metadata",
      context: "Test context",
      originatingChainId: 1 // Ethereum mainnet
    });
  }

  /// @notice Get preloaded address from seed using modulo for uniform distribution
  function _getPreloadedAddress(uint256 seed) internal view returns (address) {
    return preloadedAddresses[seed % preloadedAddresses.length];
  }

  /// @notice Deploy a token with a given token config
  /// @param config The token config
  /// @return The address of the deployed token
  function _deployTokenWithTokenConfig(IClanker.TokenConfig memory config) internal returns (address) {
    IClanker.DeploymentConfig memory deployConfig = _buildDeploymentConfig(config);
    return IClanker(ETHEREUM_FACTORY).deployToken{ value: 0 }(deployConfig);
  }

  /// @notice Build minimal valid DeploymentConfig for mainnet testing
  /// @dev Uses configuration pattern from real mainnet deployment tx
  /// 0x81d270103943d4f41c63caee6321d1654c29176ef24a0b4c109ec969bacb4ada
  function _buildPoolConfig() internal pure returns (IClanker.PoolConfig memory) {
    bytes memory poolData = abi.encode(uint24(10_000), uint24(10_000));
    return IClanker.PoolConfig({
      hook: MAINNET_HOOK, pairedToken: WETH, tickIfToken0IsClanker: -230_400, tickSpacing: 200, poolData: poolData
    });
  }

  function _buildLockerConfig(address tokenAdmin) internal pure returns (IClanker.LockerConfig memory) {
    address[] memory rewardAdmins = new address[](1);
    rewardAdmins[0] = tokenAdmin;

    address[] memory rewardRecipients = new address[](1);
    rewardRecipients[0] = tokenAdmin;

    uint16[] memory rewardBps = new uint16[](1);
    rewardBps[0] = 10_000;

    int24[] memory tickLower = new int24[](5);
    tickLower[0] = -230_400;
    tickLower[1] = -214_000;
    tickLower[2] = -202_000;
    tickLower[3] = -155_000;
    tickLower[4] = -141_000;

    int24[] memory tickUpper = new int24[](5);
    tickUpper[0] = -214_000;
    tickUpper[1] = -155_000;
    tickUpper[2] = -155_000;
    tickUpper[3] = -120_000;
    tickUpper[4] = -120_000;

    uint16[] memory positionBps = new uint16[](5);
    positionBps[0] = 1000;
    positionBps[1] = 5000;
    positionBps[2] = 1500;
    positionBps[3] = 2000;
    positionBps[4] = 500;

    bytes memory lockerData = abi.encode(true, true);

    return IClanker.LockerConfig({
      locker: MAINNET_LOCKER,
      rewardAdmins: rewardAdmins,
      rewardRecipients: rewardRecipients,
      rewardBps: rewardBps,
      tickLower: tickLower,
      tickUpper: tickUpper,
      positionBps: positionBps,
      lockerData: lockerData
    });
  }

  function _buildMevModuleConfig() internal pure returns (IClanker.MevModuleConfig memory) {
    bytes memory mevModuleData = abi.encode(uint256(666_777), uint256(41_673), uint256(90));
    return IClanker.MevModuleConfig({ mevModule: MAINNET_MEV_MODULE, mevModuleData: mevModuleData });
  }

  function _buildDeploymentConfig(IClanker.TokenConfig memory tokenConfig)
    internal
    pure
    returns (IClanker.DeploymentConfig memory)
  {
    return IClanker.DeploymentConfig({
      tokenConfig: tokenConfig,
      poolConfig: _buildPoolConfig(),
      lockerConfig: _buildLockerConfig(tokenConfig.tokenAdmin),
      mevModuleConfig: _buildMevModuleConfig(),
      extensionConfigs: new IClanker.ExtensionConfig[](0)
    });
  }
}
