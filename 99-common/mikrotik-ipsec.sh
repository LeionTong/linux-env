#!/bin/sh
# update-ipsec-mikrotik.sh

ROUTER_IP="192.168.11.1"
SSH_USER="admin"
PEER_NAME="mynet.sitechcloud.com"

show_usage() {
    echo "Usage:"
    echo " $0 <IPsec-xauth-password> # Safely update password (disable -> set -> enable)"
    echo " $0 --start                # Enable IPsec peer"
    echo " $0 --stop                 # Disable IPsec peer"
    echo " $0 --status               # Print router status info"
}

if [ "$#" -eq 0 ]; then
    show_usage >&2
    exit 1
fi

ACTION="$1"

run_ssh_cmd() {
    local cmd="$1"
    local desc="$2"
    printf "[INFO] %s...\n" "$desc"
    if ! ssh "$SSH_USER@$ROUTER_IP" "$cmd"; then
        printf "[ERROR] %s failed.\n" "$desc" >&2
        exit 1
    fi
    printf "[OK] %s succeeded.\n" "$desc"
}

run_ssh_status_cmd() {
    local cmd="$1"
    printf "\n[INFO] Executing: %s\n" "$cmd"
    printf "%s\n" "----------------------------------------"
    if ! output=$(ssh "$SSH_USER@$ROUTER_IP" "$cmd" 2>&1); then
        printf "[ERROR] Command failed.\n"
        printf "Output: %s\n" "$output"
    else
        if [ -n "$output" ]; then
            printf "%s\n" "$output"
        else
            printf "<no output>\n"
        fi
    fi
}

case "$ACTION" in
    "--stop")
        run_ssh_cmd "/ip ipsec peer disable [find name=\"$PEER_NAME\"]" "Disabling IPsec peer"
        ;;
    "--start")
        run_ssh_cmd "/ip ipsec peer enable [find name=\"$PEER_NAME\"]" "Enabling IPsec peer"
        ;;
    "--status")
        printf "[STATUS MODE] Fetching router information...\n"

        run_ssh_status_cmd "/ip/ipsec/peer/print"
        run_ssh_status_cmd "/ip/address/print"
        run_ssh_status_cmd "/ip/route/print"
        run_ssh_status_cmd "/ip/firewall/connection/print"
        run_ssh_status_cmd "/system/script/print"
        run_ssh_status_cmd "/system/scheduler/print"
	run_ssh_status_cmd "/ip/ipsec/active-peers/print"
        run_ssh_status_cmd "/ip/ipsec/installed-sa/print"

        printf "\n[SUCCESs] Status information retrieved.\n"
        ;;
    *)
        # Treat as password update
        PASSWORD="$ACTION"

        # Step 1: Disable
        run_ssh_cmd "/ip ipsec peer disable [find name=\"$PEER_NAME\"]" "Stopping peer before update"

        # Step 2: Update identity password
        printf "[INFO] Updating IPsec identity password...\n"
        if ! ssh "$SSH_USER@$ROUTER_IP" "/ip ipsec identity set [find peer=\"$PEER_NAME\"] password=\"$PASSWORD\""; then
            printf "[ERROR] Password update failed.\n" >&2
            # Try to recover: re-enable peer
            ssh "$SSH_USER@$ROUTER_IP" "/ip ipsec peer enable [find name=\"$PEER_NAME\"]" >/dev/null 2>&1
            exit 1
        fi
        printf "[OK] Password updated successfully.\n"

        # Step 3: Enable
        run_ssh_cmd "/ip ipsec peer enable [find name=\"$PEER_NAME\"]" "Starting peer after update"

        echo
        printf "[SUCCESS] Full update cycle completed.\n"
        ;;
esac
