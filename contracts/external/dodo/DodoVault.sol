// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface DodoVault {
    function querySellBase(address trader, uint256 amount) external view returns (uint256);

    function querySellQuote(address trader, uint256 amount) external view returns (uint256);

    function getMidPrice() external view returns (uint256);

    function getBaseInput() external view returns (uint256);

    function getQuoteInput() external view returns (uint256);

    function getVaultReserve() external view returns (uint256, uint256);

    function flashLoan(
        uint256 baseAmount,
        uint256 quoteAmount,
        address assetTo,
        bytes calldata data
    ) external;

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function buyShares(address to)
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function sellShares(
        uint256 shareAmount,
        address to,
        uint256 baseMinAmount,
        uint256 quoteMinAmount,
        bytes calldata data,
        uint256 deadline
    ) external returns (uint256, uint256);

    function depositQuote(uint256 amount) external returns (uint256);

    function getTotalQuoteCapital() external view returns (uint256);

    function withdrawQuote(uint256 amount) external returns (uint256);

    function getQuoteCapitalBalanceOf(address lp) external view returns (uint256);

    function getLpQuoteBalance(address lp) external view returns (uint256 lpBalance);

    function getWithdrawQuotePenalty(uint256 amount) external view returns (uint256 penalty);

    function getExpectedTarget() external view returns (uint256 baseTarget, uint256 quoteTarget);

    function sellBase(address to) external view returns (uint256 receiveQuoteAmount);

    function sellQuote(address to) external view returns (uint256 receiveBaseAmount);
}
