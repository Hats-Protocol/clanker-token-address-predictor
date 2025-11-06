// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console2 } from "forge-std/Test.sol";
import { ClankerAddressPredictor } from "../src/ClankerAddressPredictor.sol";
import { PredictAddress } from "../script/PredictAddress.s.sol";
import { IClanker } from "lib/v4-contracts/src/interfaces/IClanker.sol";
import { Clanker } from "lib/v4-contracts/src/Clanker.sol";
import { IClankerHookV2 } from "lib/v4-contracts/src/hooks/interfaces/IClankerHookV2.sol";
import { IClankerHookStaticFee } from "lib/v4-contracts/src/hooks/interfaces/IClankerHookStaticFee.sol";
import { IWETH9 } from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import { ClankerMainnetTestBase } from "./helpers/ClankerMainnetTestBase.sol";

/// forge-config: default.fuzz.runs = 32
contract ClankerAddressPredictorTest is ClankerMainnetTestBase {
  // Test-specific constants
  uint256 constant TOKEN_SUPPLY = 100_000_000_000e18;
  string constant CLANKER_WORLD_CONTEXT = '{"interface":"clanker.world","platform":"","messageId":"","id":""}';

  // Pre-loaded addresses for fuzz testing (avoids excessive RPC calls)
  address[] internal preloadedAddresses;
  Clanker internal factory;
  PredictAddress internal predictionScript;

  function setUp() public override {
    super.setUp(); // Creates mainnet fork at FORK_BLOCK
    factory = Clanker(CLANKER);

    // Generate 50 pseudorandom addresses using makeAddr
    for (uint256 i = 0; i < 50; i++) {
      preloadedAddresses.push(makeAddr(string.concat("testAddr", vm.toString(i))));
    }

    // Add zero address as edge case
    preloadedAddresses.push(address(0));

    // Deploy address prediction script
    predictionScript = new PredictAddress();
  }

  // ============ Fuzz Tests (Foundation Layer) ============

  /// @notice Fuzz test tokenAdmin parameter
  function testFuzz_predictTokenAddress_tokenAdmin(uint256 adminSeed, bytes32 salt) public {
    address admin = _getPreloadedAddress(adminSeed);

    IClanker.TokenConfig memory config = _createDefaultConfig();
    config.tokenAdmin = admin;
    config.salt = salt;

    // Predict address
    address predicted = predictionScript.predict(config);

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
    address predicted = predictionScript.predict(config);

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
    address predicted = predictionScript.predict(config);

    // Build full deployment config and deploy actual token
    address actual = _deployTokenWithTokenConfig(config);

    // Verify prediction matches reality
    assertEq(predicted, actual, "Predicted address must match actual deployment");
  }

  /// @notice Fuzz test metadata strings
  function testFuzz_predictTokenAddress_metadata(string memory image, string memory metadata) public {
    // Bound string lengths
    vm.assume(bytes(image).length <= 100);
    vm.assume(bytes(metadata).length <= 100);

    IClanker.TokenConfig memory config = _createDefaultConfig();
    config.image = image;
    config.metadata = metadata;

    // Predict address
    address predicted = predictionScript.predict(config);

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
    string memory metadata
  ) public {
    // Apply bounds
    vm.assume(bytes(name).length > 0 && bytes(name).length <= 50);
    vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 20);
    vm.assume(bytes(image).length <= 100);
    vm.assume(bytes(metadata).length <= 100);

    IClanker.TokenConfig memory config = IClanker.TokenConfig({
      tokenAdmin: _getPreloadedAddress(adminSeed),
      name: name,
      symbol: symbol,
      salt: salt,
      image: image,
      metadata: metadata,
      context: CLANKER_WORLD_CONTEXT,
      originatingChainId: block.chainid
    });

    // Predict address
    address predicted = predictionScript.predict(config);

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
      "metadata"
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
      context: CLANKER_WORLD_CONTEXT,
      originatingChainId: 1
    });

    // Expected deployed address from the real tx
    address expectedAddress = 0xd1A89f9B07a5170EDC02CE4019d300e095b11B07;

    // Predict address
    address predicted = predictionScript.predict(config);

    console2.log("Predicted:", predicted);
    console2.log("Expected:", expectedAddress);
    console2.log("Salt:", uint256(keccak256(abi.encode(config.tokenAdmin, config.salt))));

    // Verify prediction matches the actual deployed address
    assertEq(predicted, expectedAddress, "Predicted address must match real deployed token");
  }

  /// @notice Test empty strings
  function test_predictTokenAddress_emptyStrings() public {
    testFuzz_predictTokenAddress_metadata("", "");
  }

  /// @notice Test zero address admin
  function test_predictTokenAddress_zeroAddressAdmin() public {
    IClanker.TokenConfig memory config = _createDefaultConfig();
    config.tokenAdmin = address(0);

    // Predict address
    address predicted = predictionScript.predict(config);

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
      context: CLANKER_WORLD_CONTEXT,
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
    // Mock the locker's placeLiquidity to skip liquidity placement
    // This allows us to test address prediction without complex liquidity setup
    // The placeLiquidity call would need WETH and complex Uniswap V4 state
    // Function signature: placeLiquidity(LockerConfig,PoolConfig,PoolKey,uint256,address) returns (uint256)
    vm.mockCall(
      CLANKER_LP_LOCKER_FEE_CONVERSION,
      abi.encodeWithSelector(
        bytes4(
          keccak256(
            "placeLiquidity((address,address[],address[],uint16[],int24[],int24[],uint16[],bytes),(address,address,int24,int24,bytes),(address,address,uint24,int24,address),uint256,address)"
          )
        )
      ),
      abi.encode(uint256(1)) // Return tokenId = 1
    );

    IClanker.DeploymentConfig memory deployConfig = _buildDeploymentConfig(config);

    // Note: msg.value=0 is correct - ETH value is only used for extensions (dev buy, etc.)
    return IClanker(CLANKER).deployToken{ value: 0 }(deployConfig);
  }

  /// @notice Build minimal valid DeploymentConfig for mainnet testing
  /// @dev Uses configuration pattern from real mainnet deployment tx
  /// 0x81d270103943d4f41c63caee6321d1654c29176ef24a0b4c109ec969bacb4ada
  function _buildPoolConfig() internal pure returns (IClanker.PoolConfig memory) {
    // Build V2 hook initialization data with proper struct encoding
    bytes memory poolData = abi.encode(
      IClankerHookV2.PoolInitializationData({
        extension: address(0), // No pool extension for basic deployment
        extensionData: abi.encode(), // Empty extension data
        feeData: abi.encode(
          IClankerHookStaticFee.PoolStaticConfigVars({
            clankerFee: 10_000, // 1% fee (in basis points)
            pairedFee: 10_000 // 1% fee (in basis points)
          })
        )
      })
    );
    return IClanker.PoolConfig({
      hook: CLANKER_STATIC_HOOK_V2,
      pairedToken: WETH,
      tickIfToken0IsClanker: -230_400,
      tickSpacing: 200,
      poolData: poolData
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
      locker: CLANKER_LP_LOCKER_FEE_CONVERSION,
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
    return IClanker.MevModuleConfig({ mevModule: CLANKER_MEV_FEE_DECAY, mevModuleData: mevModuleData });
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
