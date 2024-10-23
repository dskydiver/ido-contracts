// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

// OpenZeppelin
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// OpenZeppelin Upgradeable
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IToken} from "./interfaces/IToken.sol";
import {ILaunch} from "./interfaces/ILaunch.sol";

contract Launch is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ILaunch
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public immutable INITIAL_OWNER;
    address public immutable TOKEN_SINGLETON;

    uint256 public softCap; // 70% of supply (0.7B)
    uint256 public hardCap; // 80% of supply (0.8B)
    uint256 public price; // token amount per 1 contribute token (without decimal)
    uint256 public purchaseLimitPerWallet; // 10% of supply (will be initialized with custom value)

    PurchasePhase public purchasePhase;

    // map of contributions
    mapping(address => Contribution) public contributions;

    uint256 private totalContribution;

    address public stableToken;
    address public token;

    constructor(address owner_, address singleton_) {
        _disableInitializers();
        INITIAL_OWNER = owner_;
        TOKEN_SINGLETON = singleton_;
    }

    function initialize(InitializeParams memory params_) external initializer {
        softCap = params_.softCap;
        hardCap = params_.hardCap;
        price = params_.price;
        purchaseLimitPerWallet = params_.purchaseLimitPerWallet;
        stableToken = params_.stableToken;

        // Initialize OwnableUpgradeable.
        __Ownable_init(INITIAL_OWNER);

        // Initialize ReentrancyGuardUpgradeable.
        __ReentrancyGuard_init();

        token = Clones.clone(TOKEN_SINGLETON);

        emit TokenCreated(token);

        // initialize the token
        IToken(token).initialize(
            address(this),
            params_.name,
            params_.symbol,
            params_.hardCap,
            params_.stableToken
        );

        purchasePhase = PurchasePhase.SOFT_PURCHASE;
    }

    function contribute(uint256 contributeAmount_) external {
        require(
            purchasePhase != PurchasePhase.COMPLETED,
            "Purchase phase completed"
        );
        require(purchasePhase != PurchasePhase.PAUSED, "Purchase phase paused");

        Contribution storage contribution = contributions[msg.sender];
        uint256 availableContributeAmount = ((hardCap -
            contribution.tokenAmount) *
            10 ** IERC20Metadata(stableToken).decimals()) / price;
        uint256 contributeAmount = Math.min(
            availableContributeAmount,
            contributeAmount_
        );

        if (purchasePhase == PurchasePhase.SOFT_PURCHASE) {
            // check purchase limit
            contributeAmount = Math.min(
                contributeAmount,
                (purchaseLimitPerWallet *
                    10 ** IERC20Metadata(token).decimals()) /
                    price -
                    contribution.stableAmount
            );
        }

        purchase(contributeAmount, msg.sender);

        // check current purchase amount
        uint256 currentPurchasedTokenAmount = IToken(token).maxSupply() -
            IToken(token).balanceOf(token);
        if (currentPurchasedTokenAmount >= hardCap) {
            purchasePhase = PurchasePhase.COMPLETED;
        } else if (currentPurchasedTokenAmount >= softCap) {
            purchasePhase = PurchasePhase.HARD_PURCHASE;
        }
    }

    function purchase(uint256 contributeAmount, address buyer) internal {
        Contribution storage contribution = contributions[buyer];
        contribution.stableAmount =
            contribution.stableAmount +
            contributeAmount;
        contribution.tokenAmount =
            contribution.tokenAmount +
            ((contributeAmount * price) /
                10 ** IERC20Metadata(token).decimals());

        IERC20(token).safeTransferFrom(token, buyer, contribution.tokenAmount);

        IERC20(stableToken).safeTransferFrom(buyer, token, contributeAmount);

        totalContribution += contributeAmount;

        emit Purchase(buyer, contributeAmount, contribution.tokenAmount);
    }

    // anyone can call this function for optional initial purchase
    function addLiquidityAndInitialBuy(uint256 buyAmount) external {
        require(
            purchasePhase == PurchasePhase.COMPLETED,
            "Purchase phase not completed"
        );
        IToken(token).addLiquidityAndInitialBuy(
            totalContribution,
            msg.sender,
            buyAmount
        );
    }

    function pause() external onlyOwner {
        require(
            purchasePhase != PurchasePhase.PAUSED,
            "Purchase phase already paused"
        );
        purchasePhase = PurchasePhase.PAUSED;
    }

    function emergencyWithdraw() external onlyOwner {
        // withdraw eth
        payable(msg.sender).transfer(address(this).balance);
    }
}
