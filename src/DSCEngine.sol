// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSC Engine
 * @author Onchain DevRel
 * @notice
 * The system is designed to be as minima as possible to allow for easy understanding and to focus on the core concepts of minting, redeeming, and liquidating.
 * This stablecoin has the properties"
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 */
contract DSCEngine is ReentrancyGuard {
    /////////////
    // Errors //
    /////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    /////////////
    // State Variables //
    /////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; // 1 * 10^10 because we want to have 18 decimals for precision
    uint256 private constant PRECISION = 1e18; 
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% collateralization ratio
    uint256 private constant LIQUIDATION_PRECISION = 100; // 100% precision for liquidation threshold
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    

    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_dscMinted;
    address[] private s_collateralTokens;


      /////////////
    // Events //
    /////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    /////////////
    // Modifiers //
    /////////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /////////////
    // Functions //
    /////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // For example
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////
    // External Function //
    /////////////

    

    /*
    * @notice follows CEI
    * @param tokenCollateralAddress The address of the token to deposit as collateral
    * @param amountCollateral The amount of the token to deposit as collateral

    **/
    function depositCollateralAndMintDsc() external {}

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

/* 
* @notice follows CEI
* @param amountDscToMint The amount of DSC to mint
* @notice they must have more collateral value than the minimum threshold after minting
*/
    function liquidateDsc() external {}

    function mintDSC(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_dscMinted[msg.sender] += amountDscToMint;
        // if they minted too much ($150 DSC, $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC() external {}

      ///////////////////////////////////////
    // Private & Internal View Functions //
    ////////////////////////////////////////

    function _getAccountInformation(address user) private view returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) {
        totalDscMinted = s_dscMinted[user];
        totalCollateralValueInUsd = _getAccountCollateralValue(user);
        // loop through all the collateral they have deposited
        // get the price of each collateral
        // calculate the value of each collateral and add it to the total collateral value
    }

    /* 
    * Returns how close to liquidation the user is. The higher the number, the closer they are to liquidation. If they are above 1, they are safe. If they are below 1, they are getting liquidated.
    * if a user goes below 1, they can be liquidated until they are above 1 again. If they are at 0.5, they can be liquidated up to 50% of their collateral until they are at 1 again.
    */ 

    function _healthFactor(address user) private view returns (uint256) {
          // total DSC minted
         // total collateral VALUE
         (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(user);
         if (totalDscMinted == 0) return type(uint256).max;
         uint256 collateralAdjustedForThreshold = (totalCollateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

         // 2000 ETH * 50 / 100 = 1000
         // 1000 / 500 DSC = 2 (safe)
         // 1000 * 50 = 5000 / 100 = (500 / 100) > 1

         return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }
  

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

        ///////////////////////////////////////
    // Public & External View Functions //
    ////////////////////////////////////////

    function _getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd){
        // loop through 
        for(uint256 i = 0; i < s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
            // get the token address
            // get the amount of collateral deposited for that token
            // get the price of that token
            // calculate the value of that collateral and add it to the total collateral value
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns(uint256){ 
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1. Eth = $2000
        // 2. The returned value from CL will be 2000 * 10^8 because of the decimals, so we need to adjust for that
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;


    }


}
