// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

// NFT
import {ERC721, ERC721Enumerable, Strings} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// Fungible
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Staking factory
import {IEIP2612} from "../interfaces/IEIP2612.sol";
import {ISUPERDEFIDistribution} from "../interfaces/ISUPERDEFIDistribution.sol";

contract SUPERDEFIDistribution is ISUPERDEFIDistribution, ERC721Enumerable {
    uint88 internal MAX_TOTAL_SUPERDEFI_SUPPLY = uint88(200_000_000_000_000_000_000_000_000);

    uint256 internal constant _pointsMultiplier = uint256(2**128);
    uint256 internal _pointsPerUnit;

    address public immutable SUPERDEFI;

    uint256 public distributableSUPERDEFI;
    uint256 public totalDepositedSUPERDEFI;
    uint256 public totalUnits;

    mapping(uint256 => Position) public positionOf;

    mapping(uint256 => uint8) public premiumMultiplierOf;

    uint256 internal immutable _zeroDPB;

    string public baseURI;

    address public owner;
    address public pendingOwner;

    uint256 internal _locked;

    constructor(
        address SUPERDEFI_,
        string memory baseURI_,
        uint256 zeroDPB_
    ) ERC721("Locked SUPERDEFI", "lSUPERDEFI") {
        require((SUPERDEFI = SUPERDEFI_) != address(0), "INVALID_TOKEN");
        owner = msg.sender;
        baseURI = baseURI_;
        _zeroDPB = zeroDPB_;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "NOT_OWNER");
        _;
    }

    modifier avoidReentrancy(string memory lockName) {
        uint256 lockId = uint256(keccak256(abi.encodePacked((lockName))));
        require(_locked != lockId, "LOCKED");
        _locked = lockId;
        _;
        _locked = uint256(0);
    }

    function acceptOwnership(address sender) external {
        require(pendingOwner == sender, "NOT_PENDING_OWNER");
        emit OwnershipAccepted(owner, sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    function proposeOwnership(address newOwner_) external onlyOwner {
        emit OwnershipProposed(owner, pendingOwner = newOwner_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function setLockPeriods(uint256[] memory durations_, uint8[] memory multipliers) external onlyOwner {
        uint256 count = durations_.length;

        for (uint256 i; i < count; ++i) {
            uint256 duration = durations_[i];
            emit LockPeriodSet(duration, premiumMultiplierOf[duration] = multipliers[i]);
        }
    }

    function lock(
        uint256 amount_,
        uint256 duration_,
        address destination_
    ) external avoidReentrancy("lock") returns (uint256 tokenId_) {
        SafeERC20.safeTransferFrom(IERC20(SUPERDEFI), msg.sender, address(this), amount_);
        return _lock(amount_, duration_, destination_);
    }

    function lockWithPermit(
        uint256 amount_,
        uint256 duration_,
        address destination_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external avoidReentrancy("lockWithPermit") returns (uint256 tokenId_) {
        IEIP2612(SUPERDEFI).permit(msg.sender, address(this), amount_, deadline_, v_, r_, s_);
        SafeERC20.safeTransferFrom(IERC20(SUPERDEFI), msg.sender, address(this), amount_);
        return _lock(amount_, duration_, destination_);
    }

    function relock(
        uint256 tokenId_,
        uint256 lockAmount_,
        uint256 duration_,
        address destination_
    ) external avoidReentrancy("relock") returns (uint256 amountUnlocked_, uint256 newTokenId_) {
        amountUnlocked_ = _unlock(msg.sender, tokenId_);
        require(lockAmount_ <= amountUnlocked_, "INSUFFICIENT_AMOUNT_UNLOCKED");
        newTokenId_ = _lock(lockAmount_, duration_, destination_);

        uint256 withdrawAmount = amountUnlocked_ - lockAmount_;

        if (withdrawAmount != uint256(0)) {
            SafeERC20.safeTransfer(IERC20(SUPERDEFI), destination_, withdrawAmount);
        }

        _updateSUPERDEFIBalance();
    }

    function unlock(uint256 tokenId_, address destination_) external avoidReentrancy("unlock") returns (uint256 amountUnlocked_) {
        amountUnlocked_ = _unlock(msg.sender, tokenId_);
        SafeERC20.safeTransfer(IERC20(SUPERDEFI), destination_, amountUnlocked_);
        _updateSUPERDEFIBalance();
    }

    function updateDistribution() external {
        uint256 totalUnitsCached = totalUnits;

        require(totalUnitsCached > uint256(0), "NO_UNIT_SUPPLY");

        uint256 newSUPERDEFI = _toUint256Safe(_updateSUPERDEFIBalance());

        if (newSUPERDEFI == uint256(0)) return;

        _pointsPerUnit += ((newSUPERDEFI * _pointsMultiplier) / totalUnitsCached);

        emit DistributionUpdated(msg.sender, newSUPERDEFI);
    }

    function withdrawableOf(uint256 tokenId_) public view returns (uint256 withdrawableSUPERDEFI_) {
        Position storage position = positionOf[tokenId_];
        return _givenWithdrawable(position.units, position.depositedSUPERDEFI, position.pointsCorrection);
    }

    function batchRelock(
        uint256[] memory tokenIds_,
        uint256 lockAmount_,
        uint256 duration_,
        address destination_
    ) external avoidReentrancy("batchRelock") returns (uint256 amountUnlocked_, uint256 newTokenId_) {
        amountUnlocked_ = _batchUnlock(msg.sender, tokenIds_);
        require(lockAmount_ <= amountUnlocked_, "INSUFFICIENT_AMOUNT_UNLOCKED");
        newTokenId_ = _lock(lockAmount_, duration_, destination_);

        uint256 withdrawAmount = amountUnlocked_ - lockAmount_;

        if (withdrawAmount != uint256(0)) {
            SafeERC20.safeTransfer(IERC20(SUPERDEFI), destination_, withdrawAmount);
        }
        _updateSUPERDEFIBalance();
    }

    function batchUnlock(uint256[] memory tokenIds_, address destination_) external avoidReentrancy("batchUnlock") returns (uint256 amountUnlocked_) {
        amountUnlocked_ = _batchUnlock(msg.sender, tokenIds_);
        SafeERC20.safeTransfer(IERC20(SUPERDEFI), destination_, amountUnlocked_);
        _updateSUPERDEFIBalance();
    }

    function getPoints(uint256 amount_, uint256 duration_) external view returns (uint256 points_) {
        return _getPoints(amount_, duration_);
    }

    function merge(uint256[] memory tokenIds_, address destination_) external returns (uint256 tokenId_) {
        uint256 count = tokenIds_.length;
        require(count > uint256(1), "MIN_2_TO_MERGE");

        uint256 points;

        for (uint256 i; i < count; ++i) {
            uint256 tokenId = tokenIds_[i];
            require(ownerOf(tokenId) == msg.sender, "NOT_OWNER");
            require(positionOf[tokenId].expiry == uint32(0), "POSITION_NOT_UNLOCKED");

            _burn(tokenId);

            points += _getPointsFromTID(tokenId);
        }

        _safeMint(destination_, tokenId_ = _generateNewTokenId(points));
    }

    function pointsOf(uint256 tokenId_) external view returns (uint256 points_) {
        require(_exists(tokenId_), "NO_TOKEN");
        return _getPointsFromTID(tokenId_);
    }

    function tokenURI(uint256 tokenId_) public view override(ISUPERDEFIDistribution, ERC721) returns (string memory tokenURI_) {
        require(_exists(tokenId_), "NO_TOKEN");
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId_)));
    }

    function _generateNewTokenId(uint256 points_) internal view returns (uint256 tokenId_) {
        return (points_ << uint256(128)) + uint128(totalSupply() + 1);
    }

    function _getPoints(uint256 amount_, uint256 duration_) internal view returns (uint256 points_) {
        return amount_ * (duration_ + _zeroDPB);
    }

    function _getPointsFromTID(uint256 tokenId_) internal pure returns (uint256 points_) {
        return tokenId_ >> uint256(128);
    }

    function _lock(
        uint256 amount_,
        uint256 duration_,
        address destination_
    ) internal returns (uint256 tokenId_) {
        require(amount_ != uint256(0) && amount_ <= MAX_TOTAL_SUPERDEFI_SUPPLY, "INVALID_AMOUNT");
        uint8 premiumMultiplier = premiumMultiplierOf[duration_];
        require(premiumMultiplier != uint8(0), "INVALID_DURATION");

        _safeMint(destination_, tokenId_ = _generateNewTokenId(_getPoints(amount_, duration_)));

        totalDepositedSUPERDEFI += amount_;

        uint96 units = uint96((amount_ * uint256(premiumMultiplier)) / uint256(100));
        totalUnits += units;
        positionOf[tokenId_] = Position({
            units: units,
            depositedSUPERDEFI: uint88(amount_),
            expiry: uint32(block.timestamp + duration_),
            created: uint32(block.timestamp),
            premiumMultiplier: premiumMultiplier,
            pointsCorrection: -_toInt256Safe(_pointsPerUnit * units)
        });

        emit LockPositionCreated(tokenId_, destination_, amount_, duration_);
    }

    function _toInt256Safe(uint256 x_) internal pure returns (int256 y_) {
        y_ = int256(x_);
        assert(y_ >= int256(0));
    }

    function _toUint256Safe(int256 x_) internal pure returns (uint256 y_) {
        assert(x_ >= int256(0));
        return uint256(x_);
    }

    function _unlock(address account_, uint256 tokenId_) internal returns (uint256 amountUnlocked_) {
        require(ownerOf(tokenId_) == account_, "NOT_OWNER");

        Position storage position = positionOf[tokenId_];
        uint96 units = position.units;
        uint88 depositedSUPERDEFI = position.depositedSUPERDEFI;
        uint32 expiry = position.expiry;

        require(expiry != uint32(0), "NO_LOCKED_POSITION");
        require(block.timestamp < uint256(expiry), "CANNOT_UNLOCK");

        amountUnlocked_ = _givenWithdrawable(units, depositedSUPERDEFI, position.pointsCorrection);

        totalDepositedSUPERDEFI -= uint256(depositedSUPERDEFI);

        totalUnits -= units;
        delete positionOf[tokenId_];
        _burn(tokenId_);
        emit LockPositionWithdrawn(tokenId_, account_, amountUnlocked_);
    }

    function _batchUnlock(address account_, uint256[] memory tokenIds_) internal returns (uint256 amountUnlocked_) {
        uint256 count = tokenIds_.length;
        require(count > uint256(1), "USE_UNLOCK");

        for (uint256 i; i < count; ++i) {
            amountUnlocked_ += _unlock(account_, tokenIds_[i]);
        }
    }

    function _updateSUPERDEFIBalance() internal returns (int256 newFundsTokenBalance_) {
        uint256 previousDistributableSUPERDEFI = distributableSUPERDEFI;
        uint256 currentDistributableSUPERDEFI = distributableSUPERDEFI = IERC20(SUPERDEFI).balanceOf(address(this)) - totalDepositedSUPERDEFI;

        return _toInt256Safe(currentDistributableSUPERDEFI) - _toInt256Safe(previousDistributableSUPERDEFI);
    }

    function _givenWithdrawable(
        uint96 units_,
        uint88 depositedSUPERDEFI_,
        int256 pointsCorrection_
    ) internal view returns (uint256 withdrawableSUPERDEFI_) {
        return
            (_toUint256Safe(_toInt256Safe(_pointsPerUnit * uint256(units_)) + pointsCorrection_) / _pointsMultiplier) + uint256(depositedSUPERDEFI_);
    }
}
