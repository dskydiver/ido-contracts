// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface ILaunch {
    // enum for puchasephase
    enum PurchasePhase {
        PAUSED,
        SOFT_PURCHASE,
        HARD_PURCHASE,
        COMPLETED
    }

    // initialize params struct
    struct InitializeParams {
        string name;
        string symbol;
        uint256 softCap;
        uint256 hardCap;
        uint256 price;
        uint256 purchaseLimitPerWallet;
    }

    // contribution struct
    struct Contribution {
        address contributor;
        uint256 ethAmount;
        uint256 tokenAmount;
    }

    function softCap() external view returns (uint256);

    function hardCap() external view returns (uint256);

    function price() external view returns (uint256);

    function purchaseLimitPerWallet() external view returns (uint256);

    function purchasePhase() external view returns (PurchasePhase);

    function contributions(
        address
    ) external view returns (address, uint256, uint256);

    function initialize(InitializeParams memory params_) external;

    function contribute() external payable;

    function addLiquidityAndInitialBuy() external payable;

    function pause() external;

    function emergencyWithdraw() external;

    event TokenCreated(address indexed token);

    event Purchase(
        address indexed buyer,
        uint256 ethAmount,
        uint256 tokenAmount
    );
}
