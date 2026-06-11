// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./PositionHandler.sol";
import "./ITransport.sol";

contract Transport is PositionHandler, Ownable2Step, ITransport {
    using SafeERC20 for *;

    uint256 constant PRECISION = 10 ** 25;

    address public override treasury;
    uint256 public override platformFee;

    constructor(
        address treasury_,
        uint256 platformFee_,
        address token_,
        uint256 tokenId_
    ) PositionHandler(token_, tokenId_) {
        _setTreasury(treasury_);
        _setFee(platformFee_);
    }

    function claimReferral(address user, uint256 amount) external override onlyOwner {
        require(user != address(0), "Claim to zero address");
        require(amount != 0, "Zero claim");

        uint256 realAmount = _withdrawPool(amount, tokenId);

        uint256 positionRewards;
        if (realAmount > amount) {
            positionRewards = realAmount - amount;
            realAmount = amount;
        }

        uint256 fee = (realAmount * platformFee) / PRECISION;

        token.safeTransfer(treasury, fee + positionRewards);
        token.safeTransfer(user, realAmount - fee);

        emit Claimed(user, realAmount - fee, fee, positionRewards);
    }

    function setTreasury(address treasury_) external override onlyOwner {
        _setTreasury(treasury_);
    }

    function setFee(uint256 fee_) external override onlyOwner {
        _setFee(fee_);
    }

    function setTokenId(uint256 tokenId_) external override onlyOwner {
        _changeTokenId(tokenId_);
    }

    function _setTreasury(address treasury_) internal {
        require(treasury_ != address(0), "Zero treasury");
        treasury = treasury_;
    }

    function _setFee(uint256 fee_) internal {
        require(fee_ <= PRECISION, "Fee too high");
        platformFee = fee_;
    }
}
