#!/bin/bash

PROXY_FILE="proxies.json"
APT_CONF="/etc/apt/apt.conf"
ENV_FILE="/etc/environment"

check_jq_installed() {
    if ! command -v jq > /dev/null 2>&1; then
        echo "Error: jq is not installed. Please install jq to use this feature."
        exit 1
    fi
}

check_proxy_status() {
    if [ -f "$APT_CONF" ]; then
        proxy_info=$(grep 'Acquire::http::Proxy' "$APT_CONF" | cut -d '"' -f 2)
        if [ -n "$proxy_info" ]; then
            server=$(echo "$proxy_info" | awk -F[/:] '{print $4}')
            port=$(echo "$proxy_info" | awk -F[/:] '{print $5}')
            echo "Proxy Status: Active"
            echo "Server: $server"
            echo "Port: $port"
            return 0  # Proxy is active
        else
            echo "Proxy Status: Inactive"
            return 1  # Proxy is inactive
        fi
    else
        echo "Proxy Status: Inactive"
        return 1  # Proxy is inactive
    fi
}

add_proxy() {
    echo -n "Enter the proxy server: "
    read server
    if [[ ! "$server" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Error: Invalid server address."
        return 1
    fi

    echo -n "Enter the proxy port: "
    read port
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid port number."
        return 1
    fi

    echo "Adding proxy settings. Please wait..."
    echo "Acquire::http::Proxy \"http://$server:$port/\";" | sudo tee "$APT_CONF" > /dev/null
    echo "Acquire::https::Proxy \"http://$server:$port/\";" | sudo tee -a "$APT_CONF" > /dev/null
    echo -e "\nhttp_proxy=http://$server:$port/\nhttps_proxy=http://$server:$port/" | sudo tee -a "$ENV_FILE" > /dev/null
    
    # Apply the changes for the current session
    source /etc/environment
    export http_proxy
    export https_proxy
    
    # Reload APT proxy settings
    sudo systemctl restart apt-daily.service
    
    echo "Proxy added successfully."
}

remove_proxy() {
    echo "Removing proxy settings. Please wait..."
    [ -f "$APT_CONF" ] && sudo rm "$APT_CONF"
    sudo sed -i '/http_proxy/d' "$ENV_FILE"
    sudo sed -i '/https_proxy/d' "$ENV_FILE"
    
    # Clear proxy settings for the current session
    unset http_proxy
    unset https_proxy
    
    # Reload APT proxy settings
    sudo systemctl restart apt-daily.service
    
    echo "Proxy removed successfully."
}

start_timer() {
    check_proxy_status
    proxy_status=$?

    if [ $proxy_status -ne 0 ]; then
        echo "Warning: The proxy is already inactive."
        echo "Starting the timer will re-enable the proxy when the timer concludes."
    fi

    echo -n "Enter the duration in seconds to disable the proxy: "
    read duration

    if [ $proxy_status -eq 0 ]; then
        remove_proxy
        echo "Proxy disabled for $duration seconds."
    else
        echo "No active proxy to disable. Timer will re-enable proxy after $duration seconds."
    fi

    sleep "$duration"

    echo "Re-enabling proxy..."
    add_proxy
    echo "Proxy re-enabled after timer expired."
}

save_proxy() {
    status=$(check_proxy_status)
    if echo "$status" | grep -q "Active"; then
        server=$(echo "$status" | grep "Server" | awk '{print $2}')
        port=$(echo "$status" | grep "Port" | awk '{print $2}')
        if [ -z "$server" ] || [ -z "$port" ]; then
            echo "Error: No active proxy to save."
            return
        fi
        proxy_entry="{\"server\": \"$server\", \"port\": \"$port\"}"

        if [ ! -f "$PROXY_FILE" ]; then
            # Create the file with the first proxy entry
            echo "[$proxy_entry]" > "$PROXY_FILE"
        else
            # Read the file, remove the last closing bracket, and append the new proxy
            sed -i '$ s/.$//' "$PROXY_FILE"
            echo ",$proxy_entry]" >> "$PROXY_FILE"
        fi
        echo "Proxy $server:$port saved successfully."
    else
        echo "No active proxy to save."
    fi
}

load_proxy() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it before running this script."
        return 1
    fi

    if [ ! -f "$PROXY_FILE" ]; then
        echo "No saved proxies found."
        return
    fi

    proxies=$(jq -r '.[] | "\(.server):\(.port)"' "$PROXY_FILE")
    if [ -z "$proxies" ]; then
        echo "Error: Failed to parse proxies."
        return
    fi

    server_list=()
    port_list=()
    counter=0

    echo "Saved proxies:"
    while IFS=: read -r server port; do
        server_list+=("$server")
        port_list+=("$port")
        counter=$((counter + 1))
        echo "$counter. Server: $server"
        echo "   Port: $port"
    done <<< "$proxies"

    if [ $counter -eq 0 ]; then
        echo "No proxies found."
        return
    fi

    echo -n "Enter the number of the proxy you want to load: "
    read choice

    if [ "$choice" -ge 1 ] && [ "$choice" -le "$counter" ]; then
        selected_server=${server_list[$((choice - 1))]}
        selected_port=${port_list[$((choice - 1))]}
        add_proxy_with_values "$selected_server" "$selected_port"
        echo "Proxy loaded: $selected_server:$selected_port"
    else
        echo "Invalid choice."
    fi
}

# Helper function to add proxy with predefined server and port
add_proxy_with_values() {
    server="$1"
    port="$2"

    echo "Adding proxy settings..."
    echo "Acquire::http::Proxy \"http://$server:$port/\";" | sudo tee "$APT_CONF" > /dev/null
    echo "Acquire::https::Proxy \"http://$server:$port/\";" | sudo tee -a "$APT_CONF" > /dev/null
    echo -e "\nhttp_proxy=http://$server:$port/\nhttps_proxy=http://$server:$port/" | sudo tee -a "$ENV_FILE" > /dev/null
    echo "Proxy added successfully."
}

# Function to load the last proxy from the saved list (for re-enabling after timer)
load_last_proxy() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it before running this script."
        return 1
    fi

    if [ ! -f "$PROXY_FILE" ]; then
        echo "No saved proxies found to re-enable."
        return
    fi

    last_proxy=$(jq -c ".[-1]" "$PROXY_FILE")
    server=$(echo "$last_proxy" | jq -r ".server")
    port=$(echo "$last_proxy" | jq -r ".port")
    add_proxy_with_values "$server" "$port"
}

delete_proxy() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it before running this script."
        return 1
    fi

    if [ ! -f "$PROXY_FILE" ]; then
        echo "No saved proxies found."
        return
    fi

    proxies=$(jq -r '.[] | "\(.server):\(.port)"' "$PROXY_FILE")
    if [ -z "$proxies" ]; then
        echo "Error: Failed to parse proxies."
        return
    fi

    server_list=()
    port_list=()
    counter=0

    echo "Saved proxies:"
    while IFS=: read -r server port; do
        server_list+=("$server")
        port_list+=("$port")
        counter=$((counter + 1))
        echo "$counter. Server: $server"
        echo "   Port: $port"
    done <<< "$proxies"

    if [ $counter -eq 0 ]; then
        echo "No proxies found."
        return
    fi

    echo -n "Enter the number of the proxy you want to delete: "
    read choice

    if [ "$choice" -ge 1 ] && [ "$choice" -le "$counter" ]; then
        selected_server=${server_list[$((choice - 1))]}
        selected_port=${port_list[$((choice - 1))]}

        echo "Deleting proxy: $selected_server:$selected_port..."

        # Rebuild the JSON file excluding the selected proxy
        jq --argjson idx "$((choice - 1))" 'del(.[$idx])' "$PROXY_FILE" > tmp_proxies.json
        mv tmp_proxies.json "$PROXY_FILE"

        echo "Proxy deleted successfully."
    else
        echo "Invalid choice."
    fi
}

show_menu() {
    echo "ProxyCLI"
    echo "v2.0.0 (08.10.2024)"
    echo "----------------------------"
    echo "1. Check proxy status"
    echo "2. Add proxy settings"
    echo "3. Remove proxy settings"
    echo "4. Start timer to disable proxy"
    echo "5. Save current proxy"
    echo "6. Load saved proxy"
    echo "7. Delete saved proxy"
    echo "8. Exit"
    echo -n "Choose an option: "
    read choice

    case $choice in
        1) check_proxy_status ;;
        2) add_proxy ;;
        3) remove_proxy ;;
        4) start_timer ;;
        5) save_proxy ;;
        6) load_proxy ;;
        7) delete_proxy ;;
        8) exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac

    echo ""
}

while true; do
	sleep 1
    show_menu
done
