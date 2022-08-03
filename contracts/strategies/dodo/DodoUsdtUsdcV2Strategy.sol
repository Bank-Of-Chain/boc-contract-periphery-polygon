// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DodoBaseV2Strategy.sol";

contract DodoUsdtUsdcV2Strategy is DodoBaseV2Strategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(_vault, _harvester);
    }

    function getLpTokenPool() internal pure override returns (address) {
        return 0x813FddecCD0401c4Fa73B092b074802440544E52;
    }

    function getBaseStakePoolAddress() internal pure override returns (address) {
        return 0x3E14D20C3052F9f70B57F148b408927e5b196068;
    }

    function getQuoteStakePoolAddress() internal pure override returns (address) {
        return 0xA2e116e5BFF780CB531C5A99F207543DCf70BD86;
    }

    function getBaseLpToken() internal pure override returns (address) {
        return 0x2C5CA709d9593F6Fd694D84971c55fB3032B87AB;
    }

    function getQuoteLpToken() internal pure override returns (address) {
        return 0xB0B417A00E1831DeF11b242711C3d251856AADe3;
    }

    function name() public pure override returns (string memory) {
        return "DodoUsdtUsdcV2Strategy";
    }
}
