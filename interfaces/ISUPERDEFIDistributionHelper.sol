// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { ISUPERDEFIDistribution } from "./ISUPERDEFIDistribution.sol";

interface ISUPERDEFIDistributionHelper {

    function getAllTokensForAccount(address SUPERDEFIDistribution_, address account_) external view returns (uint256[] memory tokenIds_);

    function getAllLockedPositionsForAccount(address SUPERDEFIDistribution_, address account_) external view returns (uint256[] memory tokenIds_, ISUPERDEFIDistribution.Position[] memory positions_, uint256[] memory withdrawables_);

}
