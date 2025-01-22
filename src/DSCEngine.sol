// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

/**
 * @title DSCEngine || DeFiStableCoinEngine
 * @author Jeremiah A.
 * @notice
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the DeFi StableCoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
import {DeFiStableCoin} from "./DeFiStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    /// errors ///
    error DSCEngine__tokenNotAllowed();
    error DSCEngine__depositCollateralFailed();
    error DSCEngine__valueShouldBeGreaterThanZero();
    error DSCEngine__tokenAddressAndPriceFeedAddressesLengthUnmatched();
    error DSCEngine__healthFactorIsBelowRequired();

    /// state variables ///
    DeFiStableCoin private immutable i_dsc;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    /// @dev Mapping collateral token to priceFeed address
    mapping(address collateralTokenAddress => address priceFeedAddress) private s_collateralTokenToPriceFeed;
    /// @dev Amount of collateral deposited by user
    ///        ||==> CollateralTokenAddress(wETH, wBTC) ==>||
    /// user==>||                                          ||
    ///                                                    ||
    ///        ||==> Amount of collateral <================||
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;

    /// @dev Mapping user address to amount of DSC they minted/created
    mapping(address user => uint256 DSCAmount) private s_userToDSCAmountMinted;
    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;

    /// events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    /// modifiers ///
    modifier shouldBeGreaterThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__valueShouldBeGreaterThanZero();
        }
        _;
    }

    modifier isAllowedCollateralToken(address collateralTokenAddress) {
        if (s_collateralTokenToPriceFeed[collateralTokenAddress] == address(0)) {
            revert DSCEngine__tokenNotAllowed();
        }
        _;
    }

    /// functions ///
    /**
     * @param collateralTokenAddresses - an array of addresses used for collateral(wETH or wBTC)
     * @param priceFeedAddresses - an array of addresses used for getting the value of collaterals. These price feed addresses will be obtained form Chainlink's price feed
     * @param _dsc - address of DeFiStableCoin
     */
    constructor(address[] memory collateralTokenAddresses, address[] memory priceFeedAddresses, address _dsc) {
        if (collateralTokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__tokenAddressAndPriceFeedAddressesLengthUnmatched();
        }

        for (uint256 i = 0; i < collateralTokenAddresses.length; i++) {
            s_collateralTokenToPriceFeed[collateralTokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(collateralTokenAddresses[i]);
        }

        i_dsc = DeFiStableCoin(_dsc);
    }

    /// external function ///
    function depositCollateralAndMintDsc() external {}

    /**
     * @notice function bellow following CEI
     * @param collateralTokenAddress - address of collateral used to borrow DSC
     * @param collateralAmount - amount of collateral that would be deposited
     */
    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount)
        external
        shouldBeGreaterThanZero(collateralAmount)
        isAllowedCollateralToken(collateralTokenAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][collateralTokenAddress] = collateralAmount;
        emit CollateralDeposited(msg.sender, collateralTokenAddress, collateralAmount);
        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), collateralAmount);

        if (!success) {
            revert DSCEngine__depositCollateralFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc(uint256 _amount) external shouldBeGreaterThanZero(_amount) nonReentrant {
        s_userToDSCAmountMinted[msg.sender] += _amount;

        /**
         * @dev if user tries to mint more DSCToken than collateral they have, revert with DSCEngine__healthFactorIsBelowRequired
         * @notice the reason is that, the health factor should be above MIN_HEALTH_FACTOR
         * @notice this helps user to not be liquidated early
         */
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    /// Private and Internal vew functions ///

    /**
     * @notice function bellow following CEI
     * Checks health factor (if user have enough collateral)
     * If not it reverts
     * @dev the commented function bellow serves the same purpose
     * it's just not broken down in to pieces
     */

    // function _revertIfHealthFactorIsBroken(address user) internal view {
    //     uint256 collateralValueInUSD;
    //     uint256 totalDSCMinted = s_userToDSCAmountMinted[user];

    //     for (uint256 i = 0; i < s_collateralTokens.length; i++) {
    //         address collateralToken = s_collateralTokens[i];
    //         uint256 collateralAmount = s_collateralDeposited[user][collateralToken];

    //         AggregatorV3Interface priceFeed = AggregatorV3Interface(s_collateralTokenToPriceFeed[collateralToken]);

    //         (, int256 price,,,) = priceFeed.latestRoundData();

    //         collateralValueInUSD += ((uint256(price) * ADDITIONAL_FEED_PRECISION) * collateralAmount) / PRECISION;
    //     }

    //     uint256 userHealthFactor = _calculateHealthFactor(totalDSCMinted, collateralValueInUSD);

    //     if (userHealthFactor < MIN_HEALTH_FACTOR) {
    //         revert DSCEngine__healthFactorIsBelowRequired();
    //     }
    // }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__healthFactorIsBelowRequired();
        }
    }

    /**
     * Returns how close to liquidation a user is
     * If a user Hf goes bellow 1 user would be liquidated
     */
    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInfo(user);
        return _calculateHealthFactor(totalDSCMinted, collateralValueInUSD);
    }

    function _getAccountInfo(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUSD)
    {
        totalDSCMinted = s_userToDSCAmountMinted[user];
        collateralValueInUSD = getAccountCollateralAmount(user);
    }

    function _calculateHealthFactor(uint256 totalDSCMinted, uint256 collateralThreshold)
        internal
        pure
        returns (uint256)
    {
        uint256 collateralThresholdLevel = (collateralThreshold * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return ((collateralThresholdLevel * PRECISION) / totalDSCMinted);
    }

    /// Public and External vew || pure functions ///

    /**
     * @dev loop through each collateral token, get the amount they have deposited, and map it to
     * the price, to get the USD value
     */
    function getAccountCollateralAmount(address user) public view returns (uint256 totalCollateralValueInUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address collateralToken = s_collateralTokens[i];
            uint256 collateralAmount = s_collateralDeposited[user][collateralToken];
            totalCollateralValueInUSD += getUSDValue(collateralToken, collateralAmount);
        }
        return totalCollateralValueInUSD;
    }

    function getUSDValue(address collateralToken, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_collateralTokenToPriceFeed[collateralToken]);

        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1ETH == 3694
        // But returned value is 3920 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
