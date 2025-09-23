#!/bin/bash
set -euo pipefail

# Source environment variables
. /opt/.env

# Configuration from environment
CRATE=indexer-service-rs
WORKSPACE_DIR=${WORKSPACE_DIR:-/workspace/indexer-rs}
# Prefer release builds by default to match dev workflow docs
PROFILE=${CARGO_PROFILE:-release}
FEATURES=${CARGO_FEATURES:-}
HOT_RELOAD=${HOT_RELOAD:-false}
PROFILER=${PROFILER:-none}

cd "$WORKSPACE_DIR"

# Generate config file (similar to existing run.sh)
tap_verifier="$(jq -r '."1337".TAPVerifier' /opt/tap-contracts.json)"
graph_tally_verifier=$(jq -r '."1337".GraphTallyCollector.address // ."1337".GraphTallyCollector' /opt/horizon.json)
subgraph_service=$(jq -r '."1337".SubgraphService.address' /opt/subgraph-service.json)

cat >/opt/config.toml <<-EOF
[indexer]
indexer_address = "${RECEIVER_ADDRESS}"
operator_mnemonic = "${INDEXER_MNEMONIC}"

[database]
postgres_url = "postgresql://postgres@postgres:${POSTGRES}/indexer_components_1"

[graph_node]
query_url = "http://graph-node:${GRAPH_NODE_GRAPHQL}"
status_url = "http://graph-node:${GRAPH_NODE_STATUS}/graphql"

[subgraphs.network]
query_url = "http://graph-node:${GRAPH_NODE_GRAPHQL}/subgraphs/name/graph-network"
recently_closed_allocation_buffer_secs = 60
syncing_interval_secs = 30

[subgraphs.escrow]
query_url = "http://graph-node:${GRAPH_NODE_GRAPHQL}/subgraphs/name/semiotic/tap"
syncing_interval_secs = 30

[blockchain]
chain_id = 1337
receipts_verifier_address = "${tap_verifier}"
receipts_verifier_address_v2 = "${graph_tally_verifier}"
subgraph_service_address = "${subgraph_service}"

[service]
free_query_auth_token = "freestuff"
host_and_port = "0.0.0.0:${INDEXER_SERVICE}"
url_prefix = "/"
serve_network_subgraph = false
serve_escrow_subgraph = false

[tap]
max_amount_willing_to_lose_grt = 1

[tap.rav_request]
timestamp_buffer_secs = 15

[tap.sender_aggregator_endpoints]
${ACCOUNT0_ADDRESS} = "http://tap-aggregator:${TAP_AGGREGATOR}"

[horizon]
enabled = true
EOF

# Resolve binary location, preferring mounted host build
BIN_CANDIDATES=(
  "/workspace/indexer-rs/target/${PROFILE}/indexer-service-rs"
  "/workspace/indexer-rs/target/release/indexer-service-rs"
  "/workspace/indexer-rs/target/debug/indexer-service-rs"
  "/usr/local/bin/indexer-service-rs"
)

for cand in "${BIN_CANDIDATES[@]}"; do
  if [ -x "$cand" ]; then
    BIN="$cand"
    break
  fi
done

if [ -z "${BIN:-}" ]; then
  echo "Error: indexer-service-rs binary not found. Build it locally (e.g., 'cargo build --release -p indexer-service-rs') and re-run."
  exit 1
fi

echo "Starting indexer-service-rs using: $BIN"
exec "$BIN" --config=/opt/config.toml
