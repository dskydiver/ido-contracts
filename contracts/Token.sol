// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

// OpenZeppelin
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// OpenZeppelin Upgradeable
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {IToken} from "./interfaces/IToken.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";

contract Token is
    Initializable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    IToken
{
    using SafeERC20 for IERC20;

    uint256 private immutable _MAX_SUPPLY; // 1 billion tokens (70% will be soft cap, 80% hard cap)
    IUniswapV2Router02 private immutable _UNISWAP_V2_ROUTER02;

    address public stableToken;

    // The date and block number when the initial liquidity was added.
    uint256 public fundedDate;
    uint256 public fundedBlock;

    uint256 public purchaseCap;
    address public uniswapV2Pair;

    event UniswapV2PairCreated(address indexed token, address indexed pair);

    event LiquidityProvided(
        address indexed token,
        uint256 tokenAmount,
        uint256 stableAmount,
        address indexed pair
    );

    constructor(address uniswap_v2_router02_) {
        _disableInitializers();
        _UNISWAP_V2_ROUTER02 = IUniswapV2Router02(uniswap_v2_router02_);
        _MAX_SUPPLY = 1_000_000_000 * (10 ** decimals());
    }

    function initialize(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint256 purchaseCap_,
        address stableToken_
    ) external initializer {
        // Grant ownership to whoever the initializer chooses. This will be the launch contract
        __Ownable_init(owner_);

        // Initialize the ERC20 token.
        __ERC20_init(name_, symbol_);

        // Initialize ERC20PermitUpgradeable.
        __ERC20Permit_init(name_);

        // Mint the total token supply to this contract.
        _mint(address(this), _MAX_SUPPLY);

        purchaseCap = purchaseCap_;

        stableToken = stableToken_;

        // Approve all to the owner which is launcher
        _approve(address(this), owner_, type(uint256).max);

        uniswapV2Pair = IUniswapV2Factory(_UNISWAP_V2_ROUTER02.factory())
            .createPair(address(this), stableToken_);

        emit UniswapV2PairCreated(address(this), uniswapV2Pair);
    }

    function addLiquidityAndInitialBuy(
        uint256 stableAmount,
        address buyer,
        uint256 initialBuyStableAmount
    ) external onlyOwner {
        // check if remainning balance is enough
        uint256 tokenAmount = balanceOf(address(this));
        require(
            tokenAmount == _MAX_SUPPLY - purchaseCap,
            "Purchase not ended yet."
        );
        _approve(
            address(this),
            address(_UNISWAP_V2_ROUTER02),
            type(uint256).max
        );
        _approve(stableToken, address(_UNISWAP_V2_ROUTER02), type(uint256).max);

        _UNISWAP_V2_ROUTER02.addLiquidity(
            address(this),
            stableToken,
            tokenAmount,
            stableAmount,
            0,
            0,
            owner(),
            block.timestamp
        );

        emit LiquidityProvided(
            address(this),
            tokenAmount,
            stableAmount,
            uniswapV2Pair
        );

        fundedDate = block.timestamp;
        fundedBlock = block.number;

        // initial buy
        if (initialBuyStableAmount > 0) {
            IERC20(stableToken).safeTransferFrom(
                buyer,
                address(this),
                initialBuyStableAmount
            );
            address[] memory path = new address[](2);
            address token0 = IUniswapV2Pair(uniswapV2Pair).token0();
            address token1 = IUniswapV2Pair(uniswapV2Pair).token1();
            if (token0 == address(this)) {
                path[0] = token1;
                path[1] = token0;
            } else {
                path[0] = token0;
                path[1] = token1;
            }
            _UNISWAP_V2_ROUTER02.swapExactTokensForTokens(
                initialBuyStableAmount,
                0,
                path,
                buyer,
                block.timestamp
            );
        }
    }

    function maxSupply() external view returns (uint256) {
        return _MAX_SUPPLY;
    }
}
