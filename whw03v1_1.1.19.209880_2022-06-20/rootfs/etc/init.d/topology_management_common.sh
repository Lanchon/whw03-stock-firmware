SERVICE_NAME="topology_management"
NAMESPACE="${SERVICE_NAME}"
ENABLED="enabled"
ENABLED_SYSCFG_NAME="${NAMESPACE}::${ENABLED}"
TOPOLOGY_MANAGEMENT_BASE_DIR=/tmp/${SERVICE_NAME}
TOPOLOGY_MANAGEMENT_BLACKLIST_DIR=$TOPOLOGY_MANAGEMENT_BASE_DIR/blacklist
TOPOLOGY_MANAGEMENT_LOCK_FILE="/tmp/.${SERVICE_NAME}.lock"
