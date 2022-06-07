// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface ISUPERDEFIDistribution is IERC721Enumerable {

    struct Position {
        uint96 units;
        uint88 depositedSUPERDEFI;
        uint32 expiry;
        uint32 created;
        uint8 premiumMultiplier;
        int256 pointsCorrection;
    }

    event OwnershipProposed(address indexed owner, address indexed pendingOwner);

    event OwnershipAccepted(address indexed previousOwner, address indexed owner);

    event LockPeriodSet(uint256 duration, uint8 premiumMultiplier);

    event LockPositionCreated(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 duration);

    event LockPositionWithdrawn(uint256 indexed tokenId, address indexed owner, uint256 amount);

    event DistributionUpdated(address indexed caller, uint256 amount);

    function SUPERDEFI() external view returns (address SUPERDEFI_);

    function distributableSUPERDEFI() external view returns (uint256 distributableSUPERDEFI_);

    function totalDepositedSUPERDEFI() external view returns (uint256 totalDepositedSUPERDEFI_);

    function totalUnits() external view returns (uint256 totalUnits_);

    function positionOf(uint256 id_) external view returns (uint96 units_, uint88 depositedSUPERDEFI_, uint32 expiry_, uint32 created_, uint8 premiumMultiplier_, int256 pointsCorrection_);

    function premiumMultiplierOf(uint256 duration_) external view returns (uint8 premiumMultiplier_);

    function baseURI() external view returns (string memory baseURI_);

    function owner() external view returns (address owner_);

    function pendingOwner() external view returns (address pendingOwner_);

    function acceptOwnership(address sender) external;

    function proposeOwnership(address newOwner_) external;

    function setBaseURI(string memory baseURI_) external;

    function setLockPeriods(uint256[] memory durations_, uint8[] memory multipliers) external;

    function lock(uint256 amount_, uint256 duration_, address destination_) external returns (uint256 tokenId_);

    function lockWithPermit(uint256 amount_, uint256 duration_, address destination_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) external returns (uint256 tokenId_);

    function relock(uint256 tokenId_, uint256 lockAmount_, uint256 duration_, address destination_) external returns (uint256 amountUnlocked_, uint256 newTokenId_);

    function unlock(uint256 tokenId_, address destination_) external returns (uint256 amountUnlocked_);

    function updateDistribution() external;

    function withdrawableOf(uint256 tokenId_) external view returns (uint256 withdrawableSUPERDEFI_);

    function batchRelock(uint256[] memory tokenIds_, uint256 lockAmount_, uint256 duration_, address destination_) external returns (uint256 amountUnlocked_, uint256 newTokenId_);

    function batchUnlock(uint256[] memory tokenIds_, address destination_) external returns (uint256 amountUnlocked_);

    function getPoints(uint256 amount_, uint256 duration_) external view returns (uint256 points_);

    function merge(uint256[] memory tokenIds_, address destination_) external returns (uint256 tokenId_);

    function pointsOf(uint256 tokenId_) external view returns (uint256 points_);

    function tokenURI(uint256 tokenId_) external view returns (string memory tokenURI_);

}
