// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

// OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IToken is IERC20, IERC20Metadata {
    function maxSupply() external view returns (uint256);

    function fundedDate() external view returns (uint256);

    function fundedBlock() external view returns (uint256);

    function uniswapV2Pair() external view returns (address);

    function purchaseCap() external view returns (uint256);

    function initialize(
        address owner_,
        string memory name,
        string memory symbol,
        uint256 purchaseCap_
    ) external;

    function addLiquidityAndInitialBuy(
        uint256 ethAmount,
        address buyer,
        uint256 initialBuyEthAmount
    ) external payable;
}
