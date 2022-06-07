// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ISUPERDEFIDistribution} from "../interfaces/ISUPERDEFIDistribution.sol";
import {ISUPERDEFIDistributionHelper} from "../interfaces/ISUPERDEFIDistributionHelper.sol";

/// @dev Stateless helper contract for external clients to reduce web3 calls to gather SUPERDEFIDistribution information related to individual accounts.
contract SUPERDEFIDistributionHelper is ISUPERDEFIDistributionHelper {
    function getAllTokensForAccount(address SUPERDEFIDistribution_, address account_) public view returns (uint256[] memory tokenIds_) {
        uint256 count = ISUPERDEFIDistribution(SUPERDEFIDistribution_).balanceOf(account_);
        tokenIds_ = new uint256[](count);

        for (uint256 i; i < count; ++i) {
            tokenIds_[i] = ISUPERDEFIDistribution(SUPERDEFIDistribution_).tokenOfOwnerByIndex(account_, i);
        }
    }

    function getAllLockedPositionsForAccount(address SUPERDEFIDistribution_, address account_)
        public
        view
        returns (
            uint256[] memory tokenIds_,
            ISUPERDEFIDistribution.Position[] memory positions_,
            uint256[] memory withdrawables_
        )
    {
        uint256[] memory tokenIds = getAllTokensForAccount(SUPERDEFIDistribution_, account_);

        uint256 allTokenCount = tokenIds.length;

        ISUPERDEFIDistribution.Position[] memory positions = new ISUPERDEFIDistribution.Position[](allTokenCount);

        uint256 validPositionCount;

        for (uint256 i; i < allTokenCount; ++i) {
            (
                uint96 units,
                uint88 depositedSUPERDEFI,
                uint32 expiry,
                uint32 created,
                uint8 premiumMultiplier,
                int256 pointsCorrection
            ) = ISUPERDEFIDistribution(SUPERDEFIDistribution_).positionOf(tokenIds[i]);

            if (expiry == uint32(0)) continue;

            tokenIds[validPositionCount] = tokenIds[i];
            positions[validPositionCount++] = ISUPERDEFIDistribution.Position(
                units,
                depositedSUPERDEFI,
                expiry,
                created,
                premiumMultiplier,
                pointsCorrection
            );
        }

        tokenIds_ = new uint256[](validPositionCount);
        positions_ = new ISUPERDEFIDistribution.Position[](validPositionCount);
        withdrawables_ = new uint256[](validPositionCount);

        for (uint256 i; i < validPositionCount; ++i) {
            positions_[i] = positions[i];
            withdrawables_[i] = ISUPERDEFIDistribution(SUPERDEFIDistribution_).withdrawableOf(tokenIds_[i] = tokenIds[i]);
        }
    }
}
