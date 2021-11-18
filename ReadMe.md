# Workflow of Naughty Price

## Timeline

[initializing time] -> [swapping time] -> [frozen time] -> [settle time]

## Operation

- NaughtyProxy: All the functions need to be called from outside

      -> PolicyCore -> deposit, redeem, claim, settle

      -> NaughtyRouter -> add/remove liquidity, swap tokens

## DOC

- Deploy Policy Token (PolicyCore.sol)

- Deploy a pool (policy - stablecoin) (PolicyCore.sol)

- Deposit to mint policy tokens (PolicyCore.sol)

  Burn policy tokens and redeem stablecoins

- Add liquidity to AMM pool (NaughtyRouter.sol)

- Remove liquidity to AMM pool (NaughtyRouter.sol)

- Swap inside the pool (NaughtyRouter.sol)

- Settle the final result from oracle (PolicyCore.sol)

- Claim your tokens if happened (PolicyCore.sol)

  Settle all tokens if not happened
