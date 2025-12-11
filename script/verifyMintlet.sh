contract=$(jq -r '.transactions[0].contractAddress' broadcast/Mintlet.s.sol/$chain/dry-run/run-latest.json)
forge verify-contract $contract Mintlet --chain $chain --verifier etherscan --show-standard-json-input > io/$chain/Mintlet.json
