contract=$(jq -r '.transactions[0].contractAddress' broadcast/Unit.s.sol/$chain/dry-run/run-latest.json)
args=$(cast abi-encode "constructor(address)" $(jq -r '.transactions[].arguments[0]' broadcast/Unit.s.sol/$chain/dry-run/run-latest.json))
forge verify-contract $contract Unit --chain $chain --verifier etherscan --show-standard-json-input > io/$chain/Unit.json
