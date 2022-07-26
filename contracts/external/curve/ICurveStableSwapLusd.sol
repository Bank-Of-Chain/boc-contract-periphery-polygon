// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface ICurveStableSwapLusd {
    function add_liquidity(uint256[2] calldata, uint256) external returns (uint256);

    function remove_liquidity(uint256, uint256[2] calldata) external returns (uint256[2] memory);

    function remove_liquidity_one_coin(
        uint256,
        int128,
        uint256
    ) external returns (uint256);

    function exchange(
        int128 from,
        int128 to,
        uint256 _from_amount,
        uint256 _min_to_amount
    ) external;

    function get_virtual_price() external view returns (uint256);

    function calc_withdraw_one_coin(uint256 _burn_amount, int128 i)
        external
        view
        returns (uint256, uint256);

    function get_dy(
        int128,
        int128,
        uint256 dx
    ) external view returns (uint256);
}
