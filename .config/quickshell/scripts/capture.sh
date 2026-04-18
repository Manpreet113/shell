#!/usr/bin/env bash
# capture.sh — Screenshot, Recording, and Color Picking helper for Quickshell

LOG_FILE="/tmp/quickshell_capture.log"
echo "--- Starting capture.sh at $(date) ---" >> "$LOG_FILE"
exec 2>> "$LOG_FILE"
set -x

SAVE_DIR_SCREENSHOTS="$HOME/Pictures/Screenshots"
SAVE_DIR_RECORDINGS="$HOME/Videos/Recordings"
mkdir -p "$SAVE_DIR_SCREENSHOTS" "$SAVE_DIR_RECORDINGS"

MODE=${1:-"area"} # area, screen, window, record_area, record_screen, stop, picker
ACTION=${2:-"copy"} # copy, save, both

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Check if a command exists
exists() { command -v "$1" >/dev/null 2>&1; }

# Helper to send notifications with fallback
send_notify() {
    notify-send "$1" "$2" "${@:3}" || echo "notify-send failed: $1 - $2" >> "$LOG_FILE"
}

# Detect audio device for gpu-screen-recorder
get_audio_device() {
    if exists gpu-screen-recorder; then
        DEVICES=$(gpu-screen-recorder --list-audio-devices)
        if echo "$DEVICES" | grep -q "default_output"; then
            echo "default_output"
        elif echo "$DEVICES" | grep -q "default"; then
            echo "default"
        else
            echo "$DEVICES" | grep "alsa_output" | head -n 1 | cut -d'|' -f1
        fi
    else
        echo "default"
    fi
}

case $MODE in
    "area")
        send_notify "Capture" "Select an area to screenshot" -u low -t 2000
        GEOM=$(slurp -d) || { send_notify "Capture" "Cancelled" -u low; exit 1; }
        if [ "$ACTION" == "copy" ]; then
            grim -g "$GEOM" - | wl-copy || send_notify "Error" "Grim failed" -u critical
            send_notify "Screenshot" "Area copied to clipboard" -i camera-photo-symbolic
        elif [ "$ACTION" == "save" ]; then
            FILE="$SAVE_DIR_SCREENSHOTS/screenshot_$TIMESTAMP.png"
            grim -g "$GEOM" "$FILE" || send_notify "Error" "Grim failed" -u critical
            send_notify "Screenshot" "Saved to $(basename "$FILE")" -i camera-photo-symbolic
        else
            FILE="$SAVE_DIR_SCREENSHOTS/screenshot_$TIMESTAMP.png"
            grim -g "$GEOM" "$FILE" || send_notify "Error" "Grim failed" -u critical
            cat "$FILE" | wl-copy
            send_notify "Screenshot" "Saved and copied to clipboard" -i camera-photo-symbolic
        fi
        ;;
    "screen")
        if [ "$ACTION" == "copy" ]; then
            grim - | wl-copy || send_notify "Error" "Grim failed" -u critical
            send_notify "Screenshot" "Screen copied to clipboard" -i camera-photo-symbolic
        else
            FILE="$SAVE_DIR_SCREENSHOTS/screen_$TIMESTAMP.png"
            grim "$FILE" || send_notify "Error" "Grim failed" -u critical
            [ "$ACTION" == "both" ] && cat "$FILE" | wl-copy
            send_notify "Screenshot" "Screen saved to $(basename "$FILE")" -i camera-photo-symbolic
        fi
        ;;
    "window")
        GEOM=$(hyprctl clients -j | jq -r '.[] | select(.workspace.id != -1) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp -d) || { send_notify "Capture" "Cancelled" -u low; exit 1; }
        if [ "$ACTION" == "copy" ]; then
            grim -g "$GEOM" - | wl-copy || send_notify "Error" "Grim failed" -u critical
            send_notify "Screenshot" "Window copied to clipboard" -i camera-photo-symbolic
        else
            FILE="$SAVE_DIR_SCREENSHOTS/window_$TIMESTAMP.png"
            grim -g "$GEOM" "$FILE" || send_notify "Error" "Grim failed" -u critical
            [ "$ACTION" == "both" ] && cat "$FILE" | wl-copy
            send_notify "Screenshot" "Window saved to $(basename "$FILE")" -i camera-photo-symbolic
        fi
        ;;
    "record_area")
        send_notify "Record" "Select an area to record" -u low -t 2000
        GEOM=$(slurp -d)
        SLURP_STATUS=$?
        if [ $SLURP_STATUS -ne 0 ]; then
            echo "slurp failed with status $SLURP_STATUS" >> "$LOG_FILE"
            send_notify "Record" "Cancelled" -u low
            exit 1
        fi
        FILE="$SAVE_DIR_RECORDINGS/recording_$TIMESTAMP.mp4"
        
        X=$(echo $GEOM | cut -d',' -f1)
        Y=$(echo $GEOM | cut -d',' -f2 | cut -d' ' -f1)
        W=$(echo $GEOM | cut -d' ' -f2 | cut -d'x' -f1)
        H=$(echo $GEOM | cut -d' ' -f2 | cut -d'x' -f2)
        
        W=$(( W / 2 * 2 ))
        H=$(( H / 2 * 2 ))

        AUDIO=$(get_audio_device)
        # Added -fallback-cpu-encoding yes to handle missing/broken VAAPI drivers
        gpu-screen-recorder -w region -region "${W}x${H}+${X}+${Y}" -f 60 -a "$AUDIO" -o "$FILE" -fallback-cpu-encoding yes &
        REC_PID=$!
        echo $REC_PID > /tmp/quickshell_record.pid
        sleep 1
        if ! ps -p $REC_PID > /dev/null; then
            send_notify "Error" "gpu-screen-recorder failed to start. Check /tmp/quickshell_capture.log" -u critical
            rm /tmp/quickshell_record.pid
        else
            send_notify "Recording" "Started recording area" -i media-record
        fi
        ;;
    "record_screen")
        FILE="$SAVE_DIR_RECORDINGS/recording_$TIMESTAMP.mp4"
        AUDIO=$(get_audio_device)
        gpu-screen-recorder -w screen -f 60 -a "$AUDIO" -o "$FILE" -fallback-cpu-encoding yes &
        REC_PID=$!
        echo $REC_PID > /tmp/quickshell_record.pid
        sleep 1
        if ! ps -p $REC_PID > /dev/null; then
            send_notify "Error" "gpu-screen-recorder failed to start. Check /tmp/quickshell_capture.log" -u critical
            rm /tmp/quickshell_record.pid
        else
            send_notify "Recording" "Started recording screen" -i media-record
        fi
        ;;
    "stop")
        if [ -f /tmp/quickshell_record.pid ]; then
            PID=$(cat /tmp/quickshell_record.pid)
            kill -INT $PID
            rm /tmp/quickshell_record.pid
            send_notify "Recording" "Stopped and saved" -i media-record
        else
            pkill -f -SIGINT '[g]pu-screen-recorder'
            send_notify "Recording" "Stopped and saved to $SAVE_DIR_RECORDINGS" -i media-record
        fi
        ;;
    "picker")
        if exists hyprpicker; then
            COLOR=$(hyprpicker -a)
            if [ -n "$COLOR" ]; then
                send_notify "Color Picker" "Copied $COLOR to clipboard" -i color-management
            fi
        else
            send_notify "Error" "hyprpicker not found" -u critical
        fi
        ;;
esac
