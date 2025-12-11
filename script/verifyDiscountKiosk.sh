contract=$(jq -r '.transactions[0].contractAddress' broadcast/DiscountKiosk.s.sol/$chain/dry-run/run-latest.json)
forge verify-contract $contract DiscountKiosk --chain $chain --verifier etherscan --show-standard-json-input > io/$chain/DiscountKiosk.json
