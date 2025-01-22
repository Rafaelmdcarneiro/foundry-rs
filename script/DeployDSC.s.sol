// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {DeFiStableCoin} from "../src/DeFiStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] collateralTokenAddresses;
    address[] priceFeedTokenAddresses;

    function run() external returns (DeFiStableCoin, DSCEngine) {
        HelperConfig helperConfig = new HelperConfig();

        (address wBTC_USDPriceFeed, address wETH_USDPriceFeed, address wBTC, address wETH, uint256 deployKey) =
            helperConfig.activeNetworkConfig();

        collateralTokenAddresses = [wBTC_USDPriceFeed, wETH_USDPriceFeed];
        priceFeedTokenAddresses = [wBTC, wETH];

        vm.startBroadcast();
        DeFiStableCoin dsc = new DeFiStableCoin();
        address dscAddress = address(dsc);
        // DSCEngine dscEngin = new DSCEngine(dscAddress);
        vm.stopBroadcast();
    }
}
