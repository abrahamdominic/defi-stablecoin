// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


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
contract DSCEngine {
    // Errors
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToMint();
    error DSCEngine__TransferFailed();

    function depositCollateralAndMintDsc() external {}
    
    function redeemCollateralForDsc() external {}
    
    function liquidateDsc() external {}
}