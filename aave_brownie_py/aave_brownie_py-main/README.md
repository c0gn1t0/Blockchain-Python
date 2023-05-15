1. Swap ETH for WETH
2. Deposit some ETH (WETH) into Aave
3. Borrow some asset with the ETH collateral
    a. Sell that borrowed asset. (short selling)
4. Repay everything back

Testing:
    Integration test: Kovan
    Unit tests: Mainnet-fork (mock all of mainnet as there are no oracles)