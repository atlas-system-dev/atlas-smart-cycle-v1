// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Daily Flow Interface
/// @notice Interface for the daily-yield product:
/// deposit principal and claim accumulated daily rewards.
interface IDailyFlow {
    /// @notice Daily product tiers based on deposited amount.
    enum DailyFlowTier {
        Core,
        Elite
    }

    /// @notice Stored order data for Daily Flow.
    /// @param owner Order owner.
    /// @param started Order start timestamp.
    /// @param finished Reward accrual end timestamp.
    /// @param lastClaimed Timestamp of last successful claim.
    /// @param amountLocked Principal deposited by user.
    /// @param amountUnclaimed Remaining gross rewards not yet claimed.
    /// @param tier Tier assigned to the order.
    /// @param tokenId Position id used for this order.
    struct OrderInfo {
        address owner;
        uint64 started;
        uint64 finished;
        uint64 lastClaimed;
        uint256 amountLocked;
        uint256 amountUnclaimed;
        DailyFlowTier tier;
        uint256 tokenId;
    }

    struct OrderInfoView {
        /// @dev Order id in contract storage.
        uint256 orderId;
        /// @dev Order owner.
        address owner;
        /// @dev Order start timestamp.
        uint64 started;
        /// @dev Reward accrual end timestamp.
        uint64 finished;
        /// @dev Last successful claim timestamp.
        uint64 lastClaimed;
        /// @dev Principal amount deposited by user.
        uint256 amountLocked;
        /// @dev Remaining gross rewards not yet claimed.
        uint256 amountUnclaimed;
        /// @dev Currently claimable gross reward amount.
        uint256 amountAvailable;
        /// @dev Tier assigned to this order.
        DailyFlowTier tier;
        /// @dev Pancake V3 position id used for this order.
        uint256 tokenId;
    }

    /// @notice Emitted when a new daily order is created.
    event Locked(
        uint256 indexed orderId,
        address indexed user,
        uint256 amountLocked,
        DailyFlowTier tier,
        uint256 lockTime
    );

    /// @notice Emitted when daily rewards are claimed.
    event Claimed(
        uint256 indexed orderId,
        address indexed user,
        uint256 daysClaimed,
        uint256 amountClaimed,
        uint256 platformFee,
        DailyFlowTier tier,
        uint256 positionRewards
    );

    /// @notice Creates a new daily order.
    /// @param amount Amount of main token to deposit.
    function lockup(uint256 amount) external;

    /// @notice Claims available daily rewards for an order.
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

    /// @notice Returns single order view by id with derived fields for frontend.
    /// @param orderId Order id.
    function getOrder(uint256 orderId) external view returns (OrderInfoView memory order);

    /// @notice Returns number of orders owned by user.
    /// @param user User address.
    function getUserOrdersCount(address user) external view returns (uint256);

    /// @notice Returns paginated user order views with derived fields for frontend.
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
