# Workflow of Naughty Price

## Timeline

[initializing time] -> [swapping time] -> [frozen time] -> [settle time]

## Operation

- NaughtyProxy: All the functions need to be called from outside

      -> PolicyCore -> deposit, redeem, claim, settle

      -> NaughtyRouter -> add/remove liquidity, swap tokens
