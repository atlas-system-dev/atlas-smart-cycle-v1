# Atlas Smart Cycle v1

Single-sided liquidity-staking contracts built on **PancakeSwap V3** (BNB Smart Chain). Users
deposit a single ERC-20 token (USDT) into a shared PancakeSwap V3 liquidity position; the contracts
record per-user orders and pay out rewards according to the chosen product and tier.

---

## How it works

1. **Deposit.** A user deposits USDT through one of the products (`LockupFlow` or `DailyFlow`). The
   amount is added as liquidity to a shared, single-sided PancakeSwap V3 position via the base
   `PositionHandler` (`increaseLiquidity`). A per-user order is recorded on-chain.
2. **Accrue.** Each order accrues a reward defined by its tier:
   - `LockupFlow` — a **fixed reward** that becomes claimable once the tier's lock period ends.
   - `DailyFlow` — a **daily reward** that accrues every day over a fixed 200-day schedule.
3. **Claim.** The user calls `claim`:
   - `LockupFlow.claim(orderId)` — after the lock period, returns principal + reward (less the
     platform fee) by removing the corresponding liquidity from the position.
   - `DailyFlow.claim(orderId)` — pays out the rewards accrued since the previous claim (less the
     platform fee). Can be called repeatedly across the 200-day schedule.
4. **Fees.** A configurable `platformFee` is taken from rewards on each claim and sent to the
   `treasury` address.

A minimum deposit of `10` USDT applies. Amounts and timing are denominated in the token's own
decimals.

---

## Architecture

All user-facing contracts inherit a common base, `PositionHandler`, which is the only component
that interacts with PancakeSwap V3.

```
                       ┌────────────────────┐
                       │   PositionHandler   │  ← all PancakeSwap V3 interaction
                       │  (add / remove      │     (increaseLiquidity / decreaseLiquidity / collect)
                       │   liquidity)        │
                       └─────────┬───────────┘
                                 │ inherits
         ┌───────────────────────┼────────────────────────┐
         │                       │                         │
   ┌───────────┐          ┌────────────┐            ┌────────────┐
   │ LockupFlow │          │  DailyFlow  │            │ Transport  │
   │ fixed-term │          │ 200-day     │            │ operator   │
   │ lock+reward│          │ daily accrual│           │ payouts    │
   └───────────┘          └────────────┘            └────────────┘
```

| Contract           | Purpose                                                                          |
|--------------------|----------------------------------------------------------------------------------|
| `PositionHandler`  | Base contract. Wraps PancakeSwap V3 add/remove-liquidity for the managed position. |
| `LockupFlow`       | Fixed-term product: user locks USDT for a tier-defined period and claims principal + a fixed reward after expiry. |
| `DailyFlow`        | Daily-accrual product: user locks USDT and claims a daily reward over a fixed 200-day schedule. The tier (Core/Elite) is selected automatically by deposit size. |
| `Transport`        | Operator contract for referral payouts from the shared position.                 |

---

## Reward schedule

Reward coefficients are stored with `PRECISION = 1e25` and `BP = 1e21`, so a coefficient `N`
corresponds to `N / 10_000` of the principal (`N = 10_000` → 100%).

### `LockupFlow` — fixed reward per term

| Tier         | Lock period | Reward on principal |
|--------------|-------------|---------------------|
| ContractTest | 10 minutes  | 0%                  |
| Launch       | 1 day       | 0.30%               |
| Momentum     | 5 days      | 2.00%               |
| Premiere     | 10 days     | 5.00%               |
| President    | 20 days     | 12.00%              |
| Imperium     | 30 days     | 22.50%              |

### `DailyFlow` — daily accrual over 200 days

| Tier  | Deposit size   | Daily reward | Total over 200 days |
|-------|----------------|--------------|---------------------|
| Core  | `< 2,000` USDT | 1.10%/day    | 220%                |
| Elite | `≥ 2,000` USDT | 1.30%/day    | 260%                |

---

## Deployment parameters

Each contract is constructed with `(treasury, platformFee, token, tokenId)`, where `tokenId` is the
PancakeSwap V3 position the contract manages.

### External dependencies (BNB Smart Chain mainnet)

| Component                                 | Address                                      |
|-------------------------------------------|----------------------------------------------|
| PancakeSwap V3 Factory                    | `0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865` |
| PancakeSwap V3 NonfungiblePositionManager | `0x46A15B0b27311cedF172AB29E4f4766fbE7F4364` |
| OpenZeppelin Contracts                    | `v4.9.6`                                     |
| Solidity                                  | `^0.8.20`                                    |

---

## Build

```bash
# Foundry (https://getfoundry.sh). OpenZeppelin v4.9.6 is pinned as a git submodule.
git clone --recurse-submodules <repo-url>
cd atlas-smart-cycle-v1
forge build
# If you cloned without submodules: forge install OpenZeppelin/openzeppelin-contracts@v4.9.6
```

`solc 0.8.20`, optimizer enabled (200 runs) — see `foundry.toml`.

## Documentation

- [White paper](./docs/atlas-system-white-paper.pdf)
- [Manifesto](./docs/atlas_manifesto.pdf)

## License

Proprietary — All Rights Reserved. See [`LICENSE`](./LICENSE).

This source is published for transparency and review only. Copying, reuse,
modification, or distribution without prior written permission is prohibited.
