// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

abstract contract HelperConfigConstants {
    uint256 ETH_MAINNET_CHAIN_ID = 1;
    uint256 ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 ETH_ANVIL_CHAIN_ID = 31337;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract HelperConfig is Script, HelperConfigConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address wBTC_USDPriceFeed;
        address wETH_USDPriceFeed;
        address wBTC;
        address wETH;
        uint256 deployKey;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        _initializeHelperConfig();
        _handleAnvilChain();
        _setActiveNetworkConfig();
    }

    function _initializeHelperConfig() internal {
        // Sepolia Configuration
        chainIdToNetworkConfig[ETH_SEPOLIA_CHAIN_ID] = NetworkConfig({
            wBTC_USDPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wETH_USDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wETH: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            deployKey: vm.envUint("PRIVATE_KEY")
        });

        // Local Anvil Configuration
        chainIdToNetworkConfig[ETH_ANVIL_CHAIN_ID] = NetworkConfig({
            wBTC_USDPriceFeed: address(0),
            wETH_USDPriceFeed: address(0),
            wBTC: address(0),
            wETH: address(0),
            deployKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }

    function _setActiveNetworkConfig() internal returns (NetworkConfig memory) {
        uint256 currentChainId = block.chainid;

        if (chainIdToNetworkConfig[currentChainId].wBTC_USDPriceFeed != address(0)) {
            activeNetworkConfig = chainIdToNetworkConfig[currentChainId];

            return activeNetworkConfig;
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function _handleAnvilChain() internal returns (NetworkConfig memory) {
        vm.startBroadcast();
        MockV3Aggregator ethMockV3Aggregator = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wETHMock = new ERC20Mock();

        MockV3Aggregator btcMockV3Aggregator = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wBTCMock = new ERC20Mock();
        vm.stopBroadcast();

        return NetworkConfig({
            wBTC_USDPriceFeed: address(btcMockV3Aggregator),
            wETH_USDPriceFeed: address(ethMockV3Aggregator),
            wBTC: address(wBTCMock),
            wETH: address(wETHMock),
            deployKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
