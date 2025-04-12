#!/usr/bin/env bash

# --- Configuration ---
# Icons (requires Nerd Font or similar)
ICON_VPN_ON="󰖂 "      # Icon for VPN connected (e.g., nf-md-vpn)
ICON_VPN_CONNECTING="󰖂 " # Icon for VPN connecting (consider a spinner or different icon?)
ICON_VPN_OFF="󰖂 "      # Icon for VPN disconnected (e.g., nf-md-vpn_off)

# Colors for Polybar/Status Bar formatting
COLOR_CONNECTED="#aaff77"  # Green
COLOR_CONNECTING="#ffcc00" # Yellow
COLOR_DISCONNECTED="#cc5555" # Red
COLOR_RESET="%{F-}"        # Reset color

# Text for different states
TEXT_DISCONNECTED="Disconnected"
TEXT_CONNECTING="Connecting..."

# --- Logic ---

# Function to get IPv4 address for a given interface
get_ip() {
    ip -4 addr show "$1" 2>/dev/null | grep -oP 'inet \K[\d.]+'
}

# Function to get a user-friendly VPN type name
get_vpn_type_name() {
    case "$1" in
        *wireguard*) echo "WireGuard" ;;
        *openvpn*)   echo "OpenVPN" ;;
        *openconnect*) echo "OpenConnect" ;;
        *vpnc*)      echo "VPNC" ;;
        *pptp*)      echo "PPTP" ;;
        *l2tp*)      echo "L2TP" ;;
        *sstp*)      echo "SSTP" ;;
        *ikev2*|*strongswan*) echo "IPSec/IKEv2" ;;
        *)           echo "VPN" ;; # Generic fallback
    esac
}

# 1. Check NetworkManager Connections
# Use terse output (-t) and specify fields (-f) for easier parsing.
# Filter based on TYPE containing 'vpn' or specific types like 'wireguard'.
# Use awk for more reliable field extraction and handling of potential colons in names.
# `exit` in awk ensures we only process the *first* active VPN found.
active_vpn_info=$(nmcli -t -f NAME,DEVICE,TYPE c s --active | awk -F: '$3 ~ /vpn|wireguard|ssh|openconnect|ikev2/ { print $1":"$2":"$3; exit }')

if [[ -n "$active_vpn_info" ]]; then
    # VPN connection found via nmcli
    VPN_NAME=$(echo "$active_vpn_info" | cut -d: -f1)
    VPN_DEVICE=$(echo "$active_vpn_info" | cut -d: -f2)
    VPN_TYPE_RAW=$(echo "$active_vpn_info" | cut -d: -f3)
    VPN_TYPE_FRIENDLY=$(get_vpn_type_name "$VPN_TYPE_RAW") # Get user-friendly name
    VPN_IP=$(get_ip "$VPN_DEVICE")

    if [[ -n "$VPN_IP" ]]; then
        # IP found, assume connected
        echo "%{F${COLOR_CONNECTED}}${ICON_VPN_ON}%{F-} ${VPN_NAME} (${VPN_TYPE_FRIENDLY}, ${VPN_IP})"
    else
        # Device active but no IP yet, assume connecting
        echo "%{F${COLOR_CONNECTING}}${ICON_VPN_CONNECTING}%{F-} ${VPN_NAME} (${VPN_TYPE_FRIENDLY}, ${TEXT_CONNECTING})"
    fi
else
    # 2. Fallback: Check for common VPN interfaces if nmcli shows no active VPN
    # Look for interfaces like tun*, wg*, ppp*
    # Prioritize wg* and tun* as they are common for WireGuard/OpenVPN
    VPN_DEVICE=""
    VPN_IP=""
    # Check WireGuard interfaces first
    for dev in $(ip -o link show | awk -F': ' '$2 ~ /^wg[0-9]+/ {print $2}'); do
        VPN_IP=$(get_ip "$dev")
        if [[ -n "$VPN_IP" ]]; then
            VPN_DEVICE=$dev
            VPN_TYPE_FRIENDLY="WireGuard?" # We guess based on interface name
            break
        fi
    done

    # If not found, check tun interfaces
    if [[ -z "$VPN_DEVICE" ]]; then
        for dev in $(ip -o link show | awk -F': ' '$2 ~ /^tun[0-9]+/ {print $2}'); do
            VPN_IP=$(get_ip "$dev")
            if [[ -n "$VPN_IP" ]]; then
                VPN_DEVICE=$dev
                VPN_TYPE_FRIENDLY="VPN?" # Generic guess (likely OpenVPN)
                break
            fi
        done
    fi

     # Add checks for ppp* or others if needed, similar structure

    if [[ -n "$VPN_DEVICE" && -n "$VPN_IP" ]]; then
        # Found an active interface via fallback
         echo "%{F${COLOR_CONNECTED}}${ICON_VPN_ON}%{F-} ${VPN_DEVICE} (${VPN_TYPE_FRIENDLY}, ${VPN_IP})"
    else
        # 3. No VPN detected by nmcli or fallback checks
        echo "%{F${COLOR_DISCONNECTED}}${ICON_VPN_OFF}%{F-} ${TEXT_DISCONNECTED}"
    fi
fi

exit 0
