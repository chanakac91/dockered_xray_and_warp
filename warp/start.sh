#!/bin/bash

# Function to check if CloudflareWARP interface exists
is_warp_interface_exists() {

    if ip link show CloudflareWARP &> /dev/null; then
        return 0
    else
        echo "Error: CloudflareWARP interface does not exist"
        return 1
    fi
}

# Function to restart CloudflareWARP client
restart_warp() {

    warp_status=$(warp-cli --accept-tos status >/dev/null)

	# Run warp deamon
	if [ ! $? -eq 0 ]; then
		echo "Starting CloudflareWARP daemon..."
		warp-svc > /dev/null 2>&1 &
		sleep 5
	fi

	# Register Warp
	if [[ $(warp-cli --accept-tos status) == *"Registration Missing"* ]]; then
		echo "Registering Warp Client..."
	  	warp-cli --accept-tos register
	  	sleep 3
	fi

	# Connect Warp
	if [[ $(warp-cli --accept-tos status) == *"Disconnected"* ]]; then
		echo "Connecting Warp..."
	  	warp-cli --accept-tos connect
	  	sleep 3
	fi
}

# Main script logic
while true; do

    if is_warp_interface_exists; then

        if ! ps -ef | grep -v grep | grep -q danted; then
            echo "Starting danted..."
            danted -D
        fi
    else
    	echo "Restarting CloudflareWARP Client..."
        restart_warp
    fi
    sleep 10
done
