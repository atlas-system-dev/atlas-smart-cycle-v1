// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Transport Interface
/// @notice Interface for referral payout withdrawals from shared liquidity position.
interface ITransport {
    /// @notice Emitted when referral payout is claimed.
    event Claimed(
        address indexed user,
        uint256 amountClaimed,
        uint256 platformFee,
        uint256 positionRewards
    );

    /// @notice Claims referral amount to the target user.
    /// @param user Receiver of payout.
    /// @param amount Requested gross amount to withdraw from position.
    function claimReferral(address user, uint256 amount) external;

    /// @notice Updates treasury address.
    /// @param treasury_ New treasury address.
    function setTreasury(address treasury_) external;

    /// @notice Updates platform fee ratio.
    /// @param fee_ New fee value in PRECISION units.
    function setFee(uint256 fee_) external;

    /// @notice Updates active Pancake V3 position id.
    /// @param tokenId_ New position id.
    function setTokenId(uint256 tokenId_) external;

    /// @notice Current treasury address.
    function treasury() external view returns (address);

    /// @notice Current platform fee ratio in PRECISION units.
    function platformFee() external view returns (uint256);
}
