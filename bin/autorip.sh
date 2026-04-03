#!/bin/bash

DRIVE="/dev/sr0"
CDROM_ID="/usr/lib/udev/cdrom_id"
MUSIC_DIR="/home/lyrionmusicserver/music"
PLUGIN_DIR="/var/lib/squeezeboxserver/Plugins/CDRipStatus"
LYRION_USER="squeezeboxserver"

SCRIPT_DIR="$PLUGIN_DIR/bin"
LOG_DIR="$PLUGIN_DIR/bin"
STATUS_FILE="$PLUGIN_DIR/autorip_status"


# --- STATUS VARIABLES -----------------------------------------------------
STATUS="0"
ARTIST=""
ALBUM=""
TRACKS=""
CURRENT_TRACK="0"
TRACK_PROGRESS=""
DISC_PROGRESS="0"
TRACK_STATE=""
QUALITY=""


write_status() {
cat > "$STATUS_FILE" <<EOF
status=$STATUS
artist=$ARTIST
album=$ALBUM
tracks=$TRACKS
current_track=$CURRENT_TRACK
track_state=$TRACK_STATE
track_progress=$TRACK_PROGRESS
disc_progress=$DISC_PROGRESS
rip_quality=$QUALITY
EOF
}

reset_status() {
STATUS="0"
ARTIST=""
ALBUM=""
TRACKS=""
CURRENT_TRACK="0"
TRACK_PROGRESS=""
DISC_PROGRESS=""
TRACK_STATE=""
QUALITY=""
write_status
}

# --- 1. CD WATCH-LAUNCHER MODE ----------------------------------------------
if [[ "$1" == "--watch" ]]; then
disc_present=0

while true; do
    if $CDROM_ID "$DRIVE" | grep -q "ID_CDROM_MEDIA=1"; then
        if [ "$disc_present" -eq 0 ]; then
            disc_present=1
            echo "[$(date)] disc detected"

            if ! pgrep -f "$SCRIPT_DIR/autorip.sh --run" >/dev/null; then
                #echo "starting $SCRIPT_DIR/autorip.sh --run"
                bash -c "$SCRIPT_DIR/autorip.sh --run" &
            fi
        fi
    else
        disc_present=0
        #echo "no disc"
    fi

    sleep 5
done

fi

# --- 2. REAL WORK MODE ----------------------------------------------------
if [[ "$1" == "--run" ]]; then
    echo "[$(date)] Starting CD rip..." >> "$LOG_DIR/autorip.log" 2>&1 &

    STATUS="1"
    write_status

    # 1. Check if an audio CD is present
    if ! cdparanoia -Q &>/dev/null; then
        echo "No audio CD detected" >> "$LOG_DIR/autorip.log"
        reset_status
        eject "$DRIVE"
        #espeak -v fr -s 120 "Pas de Musique"
        exit 0
    fi

    # 2. Rip the CD
	XDG_CONFIG_HOME="$SCRIPT_DIR" HOME="$SCRIPT_DIR"  whipper cd rip --unknown --output-directory "$MUSIC_DIR" 2>&1 | tee >(while IFS= read -r line
	do
	    # Output to console
	    echo "$line"


        # --- ARTIST -------------------------------------------------------

        if [[ -z "$ARTIST" && "$line" =~ ^Artist[[:space:]]*:[[:space:]](.+) ]]; then
            ARTIST="${BASH_REMATCH[1]}"
            write_status
        fi

        # --- ALBUM --------------------------------------------------------

        if [[ -z "$ALBUM" && "$line" =~ ^Title[[:space:]]*:[[:space:]](.+) ]]; then
            ALBUM="${BASH_REMATCH[1]}"
	    STATUS="2"
            write_status
        fi

        # --- READING TABLE -------------------------------------------------

	if [[ "$line" =~ Reading[[:space:]]+table[[:space:]]*([0-9]{1,3})[[:space:]]*% ]]; then
	        DISC_PROGRESS="${BASH_REMATCH[1]}"
	        write_status
	fi

        # --- TRACK COUNT --------------------------------------------------

        if [[ "$line" =~ ([0-9]+)\ audio\ tracks ]]; then
            TRACKS="${BASH_REMATCH[1]}"
            write_status
        fi

        # --- CURRENT TRACK ------------------------------------------------

        if [[ "$line" =~ ripping\ track\ ([0-9]+)\ of\ ([0-9]+) ]]; then
            CURRENT_TRACK="${BASH_REMATCH[1]}"
            write_status
        fi
    done)

    # 3. Eject when done
    eject "$DRIVE"

    # 4. Trigger LMS rescan
    curl -s "http://localhost:9000/music/scan?rescan=1" >/dev/null

    echo "[$(date)] Done." >> "$LOG_DIR/autorip.log" 2>&1 &
    reset_status
    exit 0
fi

# --- 3. CONFIGURATION  MODE -----------------------------------------------

if [[ "$1" == "--configure" ]]; then

if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi


	echo ""
        echo "Updating system"
	echo ""
    apt update
    apt upgrade -y
	echo ""
    echo "Installing Whipper"
	echo ""
    sudo apt install -y whipper
	echo ""
    echo "Detecting CD drive Offset for Whipper. It will take time. Insert a well known disc first"

        # Loop until user types Y or N
        while true; do
            read -p "Do you want to continue? (Y/N): " choice
            case "$choice" in
                [Yy]) 
                    echo "Continuing..."
                    if $CDROM_ID "$DRIVE" | grep -q "ID_CDROM_MEDIA=1"; then
                    echo "disc detected"
		    if ! cdparanoia -Q &>/dev/null; then
			echo "No audio CD detected" 
			eject "$DRIVE"
		    else
                    	break
		    fi
		    else
			echo "Please insert Disc"
		    fi
                    ;;
                [Nn]) 
                    echo "Aborting."
                    exit 1
                    ;;
                *) 
                    echo "Please type Y or N."
                    ;;
            esac
        done
	
	rm "$SCRIPT_DIR/whipper/whipper.conf"
	XDG_CONFIG_HOME="$SCRIPT_DIR" HOME="$SCRIPT_DIR" whipper offset find
	echo "Whipper Configuration file was saved in:"
	echo "$SCRIPT_DIR/whipper/whipper.conf"

	echo ""
	echo ""
	echo "Configuring automatic ripping"
    
    chown -R $LYRION_USER:nogroup $PLUGIN_DIR
	usermod -aG cdrom $LYRION_USER
	echo "Allowed Lyrion Music Server to eject discs: $LYRION_USER"

# Replace placeholders with actual values
sed \
    -e "s|__USER__|$LYRION_USER|g" \
    -e "s|__SCRIPT_PATH__|$SCRIPT_DIR/autorip.sh|g" \
    "$SCRIPT_DIR/autorip.service.template" > "/etc/systemd/system/autorip.service"

# Reload systemd to pick up the new service
systemctl daemon-reload
systemctl restart autorip.service

echo "Service is now runing under autorip.service"
echo "The Service file was saved in /etc/systemd/system/autorip.service"
echo ""
systemctl status autorip.service
echo ""
echo "Finished config. Ejecting disc..."
eject "$DRIVE"
exit 0

fi


# --- 4. DEFAULT MODE ------------------------------------------------------
echo "Usage: $0 --watch | --run | --configure"
exit 1
