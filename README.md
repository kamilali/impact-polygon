# Impact (Polygon)

To run the test node:
```shell
npx hardhat node
```

To deploy contracts (specify network):
```shell
npx hardhat run scripts/<deployment script> --network <network - e.g. localhost>
```

To verify contracts:
```shell
npx hardhat verify --network <network - e.g. kovan> --constructor-args etherscan-<args file suffix>.js <contract address>
```

To run test app:
```shell
npm run dev
```

Other useful commands:
```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
```
