#!/usr/bin/env bash

# Ensure 'fuser' is installed for the force feature
if ! command -v fuser &> /dev/null; then
    echo "Installing psmisc (required for force unmount)..."
    sudo apt update && sudo apt install psmisc -y
fi

IFS=$'\n'
devices=($(lsblk -ln -o NAME,SIZE,MOUNTPOINT | awk '$3 ~ /^\/(media|mnt)/ {print "/dev/"$1 " ["$2"] at "$3}'))

if [ ${#devices[@]} -eq 0 ]; then
    echo "No USB devices found."
    exit 1
fi

echo "--- USB Ejector (With Force Option) ---"
PS3="Choose a device: "

select choice in "${devices[@]}" "Exit"; do
    [ "$choice" = "Exit" ] || [ -z "$choice" ] && exit 0

    target=$(echo "$choice" | cut -d' ' -f1)
    mountpoint=$(lsblk -no MOUNTPOINT "$target")

    echo "Syncing and unmounting $target..."
    sync
    
    if sudo umount "$target"; then
        sudo eject "${target%[0-9]*}" 2>/dev/null
        echo "Done! Safe to remove."
    else
        echo "------------------------------------------------"
        echo "ERROR: Device is BUSY!"
        echo "The following processes are using $mountpoint:"
        sudo fuser -v "$mountpoint"
        echo "------------------------------------------------"
        read -p "Would you like to FORCE unmount by killing these processes? (y/n): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "Killing processes and forcing unmount..."
            # -k kills, -m identifies the mount, -i asks for confirmation (removed for speed)
            sudo fuser -km "$mountpoint" 
            sleep 1
            sudo umount -l "$target"
            sudo eject "${target%[0-9]*}" 2>/dev/null
            echo "Forced unmount complete."
        else
            echo "Aborted. Please close the files manually."
        fi
    fi
    break
done
