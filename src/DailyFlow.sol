// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./PositionHandler.sol";
import "./IDailyFlow.sol";

contract DailyFlow is PositionHandler, ReentrancyGuard, Ownable2Step, IDailyFlow {
    using SafeERC20 for *;

    uint256 constant PRECISION = 10 ** 25;
    uint256 constant BP = 10 ** 21;
    uint256 constant MIN_USDT_AMOUNT = 10;
    uint256 constant DAILY_REWARDS_COUNT = 200;

    address public override treasury;
    uint256 public override platformFee;

    mapping(uint256 orderId => IDailyFlow.OrderInfo orderInfo) internal _orderInfos;
    mapping(address user => uint256[] index) internal _infoByUser;

    uint256 public override nextOrderId;

    constructor(
        address treasury_,
        uint256 platformFee_,
        address token_,
        uint256 tokenId_
    ) PositionHandler(token_, tokenId_) {
        _setTreasury(treasury_);
        _setFee(platformFee_);
    }

    function lockup(uint256 amount) external override nonReentrant {
        require(amount >= MIN_USDT_AMOUNT * 10 ** tokenDecimals, "Amount too small");

        uint256 orderId = nextOrderId;
        nextOrderId++;

        amount = _depositPool(amount, tokenId);
        
        IDailyFlow.OrderInfo storage orderInfo = _orderInfos[orderId];

        uint64 timeNow = uint64(block.timestamp);
        IDailyFlow.DailyFlowTier tier = amount < 2000 * 10 ** tokenDecimals
            ? IDailyFlow.DailyFlowTier.Core
            : IDailyFlow.DailyFlowTier.Elite;

        orderInfo.owner = msg.sender;
        orderInfo.started = timeNow;
        orderInfo.finished = timeNow + 200 days;
        orderInfo.lastClaimed = timeNow;
        orderInfo.amountLocked = amount;
        orderInfo.amountUnclaimed = ((amount * _getRewardRate(tier)) / PRECISION) * DAILY_REWARDS_COUNT;
        orderInfo.tier = tier;
        orderInfo.tokenId = tokenId;

        _infoByUser[msg.sender].push(orderId);

        emit Locked(orderId, msg.sender, amount, tier, timeNow);
    }

    function claim(uint256 orderId) external override nonReentrant() {
        IDailyFlow.OrderInfo storage orderInfo = _orderInfos[orderId];

        require(orderInfo.owner == msg.sender, "Not the owner");

        (uint256 rewardTotal, uint256 daysAlreadyRewared, uint256 daysMustBeRewared) = _getPendingRewardsAmount(orderInfo);
        require(daysAlreadyRewared < 200, "Claimed everything");
        require(daysAlreadyRewared < daysMustBeRewared, "No unclaimed rewards");

        uint256 daysToClaim = daysMustBeRewared - daysAlreadyRewared;
        uint256 fee = rewardTotal * platformFee / PRECISION;

        uint256 amount = _withdrawPool(rewardTotal, orderInfo.tokenId);
        uint256 positionRewards;
        if (amount > rewardTotal) {
            positionRewards = amount - rewardTotal;
            amount = rewardTotal;
        }

        token.safeTransfer(treasury, fee + positionRewards);
        token.safeTransfer(msg.sender, amount - fee);

        orderInfo.lastClaimed = uint64(block.timestamp);
        orderInfo.amountUnclaimed -= amount;

        emit Claimed(orderId, msg.sender, daysToClaim, amount - fee, fee, orderInfo.tier, positionRewards);
    }

    function getOrder(uint256 orderId) public view override returns (IDailyFlow.OrderInfoView memory order) {
        IDailyFlow.OrderInfo storage orderInfo = _orderInfos[orderId];
        (uint256 amountAvailable,,) = _getPendingRewardsAmount(orderInfo);

        order = IDailyFlow.OrderInfoView({
            orderId: orderId,
            owner: orderInfo.owner,
            started: orderInfo.started,
            finished: orderInfo.finished,
            lastClaimed: orderInfo.lastClaimed,
            amountLocked: orderInfo.amountLocked,
            amountUnclaimed: orderInfo.amountUnclaimed,
            amountAvailable: amountAvailable,
            tier: orderInfo.tier,
            tokenId: orderInfo.tokenId
        });
    }

    function getUserOrdersCount(address user) external view override returns (uint256) {
        return _infoByUser[user].length;
    }

    function getUserOrders(address user, uint256 from, uint256 number) public view override returns (IDailyFlow.OrderInfoView[] memory orders) {
        uint256[] storage indexes = _infoByUser[user];

        uint256 indexesLength = indexes.length;
        if (from >= indexesLength) return orders;
        if (from + number > indexesLength) {
            number = indexesLength - from;
        }

        orders = new IDailyFlow.OrderInfoView[](number);

        for (uint256 i = 0; i < number; i++) {
            orders[i] = getOrder(indexes[from + i]);
        }
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

    function _getRewardRate(IDailyFlow.DailyFlowTier tier) internal pure returns (uint256 rewardRate) {
        if (tier == IDailyFlow.DailyFlowTier.Core) {
            return 110 * BP;
        } else {
            return 130 * BP;
        }
    }

    function _getPendingRewardsAmount(IDailyFlow.OrderInfo storage orderInfo)
        internal
        view
        returns (
            uint256 pendingRewards,
            uint256 daysAlreadyRewared,
            uint256 daysMustBeRewared
        )
    {
        uint64 started = orderInfo.started;
        uint64 lastClaimed = orderInfo.lastClaimed;
        daysAlreadyRewared = (lastClaimed - started) / 1 days;
        daysMustBeRewared = (block.timestamp - started) / 1 days;
        if (daysMustBeRewared > 200) {
            daysMustBeRewared = 200;
        }

        if (daysAlreadyRewared >= 200) {
            return (0, daysAlreadyRewared, daysMustBeRewared);
        }
        if (daysAlreadyRewared >= daysMustBeRewared) {
            return (0, daysAlreadyRewared, daysMustBeRewared);
        }

        uint256 daysToClaim = daysMustBeRewared - daysAlreadyRewared;
        uint256 dailyReward = (orderInfo.amountLocked * _getRewardRate(orderInfo.tier)) / PRECISION;
        pendingRewards = dailyReward * daysToClaim;
    }
}
