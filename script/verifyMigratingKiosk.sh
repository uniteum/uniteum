contract=$(jq -r '.transactions[0].contractAddress' broadcast/MigratingKiosk.s.sol/$chain/dry-run/run-latest.json)
forge verify-contract $contract MigratingKiosk --chain $chain --verifier etherscan --show-standard-json-input > io/$chain/MigratingKiosk.json
