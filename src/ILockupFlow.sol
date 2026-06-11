// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Lockup Flow Interface
/// @notice Interface for the fixed-term lockup product:
/// deposit once, claim principal + reward after lockup period.
interface ILockupFlow {
    /// @notice Available lockup plans.
    enum LockupFlowTier {
        ContractTest,
		Launch,
		Momentum,
        Premiere,
        President,
        Imperium
    }

    /// @notice Stored order data for Lockup Flow.
    /// @param owner Order owner.
    /// @param started Lock start timestamp.
    /// @param finished Lock end timestamp.
    /// @param amountLocked Principal deposited by user.
    /// @param amountEarned Principal + gross reward.
    /// @param amountReturned Net amount intended for user after platform fee.
    /// @param tier Selected lockup tier.
    /// @param tokenId Position id used for this order.
    /// @param notClaimed True while order is still claimable.
    struct OrderInfo {
        address owner;
        uint64 started;
        uint64 finished;
        uint256 amountLocked;
        uint256 amountEarned;
        uint256 amountReturned;
        LockupFlowTier tier;
        uint256 tokenId;
        bool notClaimed;
    }

    /// @notice View model for frontend consumption.
    /// @param orderId Order id in contract storage.
    /// @param owner Order owner.
    /// @param started Lock start timestamp.
    /// @param finished Lock end timestamp.
    /// @param amountLocked Principal deposited by user.
    /// @param amountEarned Principal + gross reward.
    /// @param amountReturned Net amount intended for user after platform fee.
    /// @param tier Selected lockup tier.
    /// @param tokenId Position id used for this order.
    /// @param notClaimed True while order is still claimable.
    struct OrderInfoView {
        uint256 orderId;
        address owner;
        uint64 started;
        uint64 finished;
        uint256 amountLocked;
        uint256 amountEarned;
        uint256 amountReturned;
        LockupFlowTier tier;
        uint256 tokenId;
        bool notClaimed;
    }

    /// @notice Emitted when a new lockup order is created.
    event Locked(
        uint256 indexed orderId,
        address indexed user,
        uint256 amountLocked,
        uint256 amountEarned,
        uint256 amountReturned,
        LockupFlowTier tier,
        uint256 lockTime,
        uint256 unlockTime
    );

    /// @notice Emitted when a lockup order is claimed.
    event Claimed(
        uint256 indexed orderId,
        address indexed user,
        LockupFlowTier tier,
        uint256 amountLocked,
        uint256 reward,
        uint256 platformFee,
        uint256 positionRewards
    );

    /// @notice Creates a lockup order.
    /// @param amount Amount of main token to lock.
    /// @param tier Selected lockup tier.
    function lockup(uint256 amount, LockupFlowTier tier) external;

    /// @notice Claims a matured order.
    /// @param orderId Target order id.
    function claim(uint256 orderId) external;

    /// @notice Updates treasury address.
    /// @param treasury_ New treasury address.
    function setTreasury(address treasury_) external;

    /// @notice Updates platform fee ratio.
    /// @param fee_ New fee value in PRECISION units.
    function setFee(uint256 fee_) external;

    /// @notice Updates active Pancake V3 position id.
    /// @param tokenId_ New position id.
    function setTokenId(uint256 tokenId_) external;

    /// @notice Returns single order view by id.
    /// @param orderId Order id.
    function getOrder(uint256 orderId) external view returns (OrderInfoView memory order);

    /// @notice Returns number of orders owned by user.
    /// @param user User address.
    function getUserOrdersCount(address user) external view returns (uint256);

    /// @notice Returns paginated user order views.
    /// @param user User address.
    /// @param from Start index in user's order index list.
    /// @param number Max number of records to return.
    function getUserOrders(address user, uint256 from, uint256 number) external view returns (OrderInfoView[] memory orders);

    /// @notice Current treasury address.
    function treasury() external view returns (address);

    /// @notice Current platform fee ratio in PRECISION units.
    function platformFee() external view returns (uint256);

    /// @notice Next order id to be assigned.
    function nextOrderId() external view returns (uint256);
}
