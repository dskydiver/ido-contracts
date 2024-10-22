// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

// OpenZeppelin
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
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
    uint256 public price; // token amount per wei
    uint256 public purchaseLimitPerWallet; // 10% of supply (will be initialized with custom value)

    PurchasePhase public purchasePhase;

    // map of contributions
    mapping(address => Contribution) public contributions;

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
            params_.hardCap
        );

        purchasePhase = PurchasePhase.SOFT_PURCHASE;
    }

    function contribute() external payable {
        require(msg.value > 0, "Contribution amount must be greater than 0");
        require(
            purchasePhase != PurchasePhase.COMPLETED,
            "Purchase phase completed"
        );
        require(purchasePhase != PurchasePhase.PAUSED, "Purchase phase paused");

        Contribution storage contribution = contributions[msg.sender];
        uint256 availableEthAmount = (hardCap - contribution.tokenAmount) /
            price;
        uint256 ethAmount = Math.min(availableEthAmount, msg.value);

        if (purchasePhase == PurchasePhase.SOFT_PURCHASE) {
            // check purchase limit
            ethAmount = Math.min(
                ethAmount,
                purchaseLimitPerWallet / price - contribution.ethAmount
            );
        }

        purchase(ethAmount, msg.sender);

        if (msg.value > ethAmount) {
            payable(msg.sender).transfer(msg.value - ethAmount);
        }

        // check current purchase amount
        uint256 currentPurchasedTokenAmount = IToken(token).maxSupply() -
            IToken(token).balanceOf(token);
        if (currentPurchasedTokenAmount >= hardCap) {
            purchasePhase = PurchasePhase.COMPLETED;
        } else if (currentPurchasedTokenAmount >= softCap) {
            purchasePhase = PurchasePhase.HARD_PURCHASE;
        }
    }

    function purchase(uint256 ethAmount, address buyer) internal {
        Contribution storage contribution = contributions[buyer];
        contribution.ethAmount = contribution.ethAmount + ethAmount;
        contribution.tokenAmount =
            contribution.tokenAmount +
            (ethAmount * price);

        IToken(token).transferFrom(token, buyer, contribution.tokenAmount);

        emit Purchase(buyer, ethAmount, contribution.tokenAmount);
    }

    // anyone can call this function for optional initial purchase
    function addLiquidityAndInitialBuy() external payable {
        require(
            purchasePhase == PurchasePhase.COMPLETED,
            "Purchase phase not completed"
        );
        IToken(token).addLiquidityAndInitialBuy{value: address(this).balance}(
            address(this).balance - msg.value,
            msg.sender,
            msg.value
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
