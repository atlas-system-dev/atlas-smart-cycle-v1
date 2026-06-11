// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./PositionHandler.sol";
import "./ILockupFlow.sol";

contract LockupFlow is PositionHandler, ReentrancyGuard, Ownable2Step, ILockupFlow {
    using SafeERC20 for *;

    uint256 constant PRECISION = 10 ** 25;
    uint256 constant BP = 10 ** 21;
    uint256 constant MIN_USDT_AMOUNT = 10;

    address public override treasury;
    uint256 public override platformFee;

    mapping(uint256 orderId => ILockupFlow.OrderInfo orderInfo) internal _orderInfos;
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

    function lockup(uint256 amount, ILockupFlow.LockupFlowTier tier) external override nonReentrant {
        require(amount >= MIN_USDT_AMOUNT * 10 ** tokenDecimals, "Amount too small");

        uint256 orderId = nextOrderId;
        nextOrderId++;

        amount = _depositPool(amount, tokenId);

        ILockupFlow.OrderInfo storage orderInfo = _orderInfos[orderId];

        uint64 timeNow = uint64(block.timestamp);
        uint64 deadline = timeNow + _getLockupTime(tier);
        uint256 reward = _getRewards(tier, amount);
        uint256 amountReturned = amount + (reward * (PRECISION - platformFee) / PRECISION);

        orderInfo.owner = msg.sender;
        orderInfo.started = timeNow;
        orderInfo.finished = deadline;
        orderInfo.amountLocked = amount;
        orderInfo.amountEarned = amount + reward;
        orderInfo.amountReturned = amountReturned;
        orderInfo.tier = tier;
        orderInfo.tokenId = tokenId;
        orderInfo.notClaimed = true;

        _infoByUser[msg.sender].push(orderId);

        emit Locked(orderId, msg.sender, amount, amount + reward, amountReturned, tier, timeNow, deadline);
    }

    function claim(uint256 orderId) external override nonReentrant() {
        ILockupFlow.OrderInfo storage orderInfo = _orderInfos[orderId];

        require(orderInfo.owner == msg.sender, "Not the owner");
        require(orderInfo.notClaimed, "Order already claimed or not exist");
        require(orderInfo.finished < block.timestamp, "Not yet time to claim");

        orderInfo.notClaimed = false;

        uint256 amount = _withdrawPool(orderInfo.amountEarned, orderInfo.tokenId);
        uint256 amountEarned = orderInfo.amountEarned;
        uint256 amountLocked = orderInfo.amountLocked;
        uint256 positionRewards;

        if (amount > amountEarned) {
            positionRewards = amount - amountEarned;
            amount = amountEarned;
        }
        uint256 fee = amountEarned - orderInfo.amountReturned;

        token.safeTransfer(treasury, fee + positionRewards);
        token.safeTransfer(msg.sender, amount - fee);

        emit Claimed(orderId, msg.sender, orderInfo.tier, amountLocked, amount - amountLocked - fee, fee, positionRewards);
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

    function getOrder(uint256 orderId) public view override returns (ILockupFlow.OrderInfoView memory order) {
        ILockupFlow.OrderInfo storage orderInfo = _orderInfos[orderId];

        order = ILockupFlow.OrderInfoView({
            orderId: orderId,
            owner: orderInfo.owner,
            started: orderInfo.started,
            finished: orderInfo.finished,
            amountLocked: orderInfo.amountLocked,
            amountEarned: orderInfo.amountEarned,
            amountReturned: orderInfo.amountReturned,
            tier: orderInfo.tier,
            tokenId: orderInfo.tokenId,
            notClaimed: orderInfo.notClaimed
        });
    }

    function getUserOrdersCount(address user) external view override returns (uint256) {
        return _infoByUser[user].length;
    }

    function getUserOrders(address user, uint256 from, uint256 number) public view override returns (ILockupFlow.OrderInfoView[] memory orders) {
        uint256[] storage indexes = _infoByUser[user];

        uint256 indexesLength = indexes.length;
        if (from >= indexesLength) return orders;
        if (from + number > indexesLength) {
            number = indexesLength - from;
        }

        orders = new ILockupFlow.OrderInfoView[](number);

        for (uint256 i = 0; i < number; i++) {
            orders[i] = getOrder(indexes[from + i]);
        }
    }

    function _setTreasury(address treasury_) internal {
        require(treasury_ != address(0), "Zero treasury");
        treasury = treasury_;
    }

    function _setFee(uint256 fee_) internal {
        require(fee_ <= PRECISION, "Fee too high");
        platformFee = fee_;
    }

	function _getLockupTime(ILockupFlow.LockupFlowTier tier) internal pure returns (uint64 time) {
		if (tier == ILockupFlow.LockupFlowTier.ContractTest) {
			return 10 minutes;
		} else if (tier == ILockupFlow.LockupFlowTier.Launch) {
			return 1 days;
		} else if (tier == ILockupFlow.LockupFlowTier.Momentum) {
			return 5 days;
		} else if (tier == ILockupFlow.LockupFlowTier.Premiere) {
			return 10 days;
		} else if (tier == ILockupFlow.LockupFlowTier.President) {
			return 20 days;
		} else if (tier == ILockupFlow.LockupFlowTier.Imperium) {
			return 30 days;
		} else {
			revert("Invalid tier");
		}
	}

	function _getRewards(ILockupFlow.LockupFlowTier tier, uint256 amount) internal pure returns (uint256 rewards) {
    if (tier == ILockupFlow.LockupFlowTier.ContractTest) {
        rewards = 0;
    } else if (tier == ILockupFlow.LockupFlowTier.Launch) {
        rewards = (amount * (30 * BP)) / PRECISION;
    } else if (tier == ILockupFlow.LockupFlowTier.Momentum) {
        rewards = (amount * (200 * BP)) / PRECISION;
    } else if (tier == ILockupFlow.LockupFlowTier.Premiere) {
        rewards = (amount * (500 * BP)) / PRECISION;
    } else if (tier == ILockupFlow.LockupFlowTier.President) {
        rewards = (amount * (1200 * BP)) / PRECISION;
    } else if (tier == ILockupFlow.LockupFlowTier.Imperium) {
        rewards = (amount * (2250 * BP)) / PRECISION;
    } else {
        revert("Invalid tier");
    }
}

}
