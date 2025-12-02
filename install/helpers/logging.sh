#!/bin/bash
# This file generally shouldn't be run directly, it is run by all.sh
set -euo pipefail

hjarch_start_log_output() {
    local log_file="$1"

    local ANSI_SAVE_CURSOR="\033[s"
    local ANSI_RESTORE_CURSOR="\033[u"
    local ANSI_CLEAR_LINE="\033[2K"
    local ANSI_HIDE_CURSOR="\033[?25l"
    local ANSI_RESET="\033[0m"
    local ANSI_GRAY="\033[90m"

    # Save cursor position and hide it
    printf $ANSI_SAVE_CURSOR
    printf $ANSI_HIDE_CURSOR

    (
        local log_lines=20
        local max_line_width=$((LOGO_WIDTH - 4))

        while true; do
            # Read last N lines into an array
            readarray -t current_lines < <(tail -n $log_lines "$log_file" 2>/dev/null)

            # Build output buffer with escape sequences
            output=""
            for ((i = 0; i < log_lines; i++)); do
                line="${current_lines[i]:-}"

                # Truncate if needed
                if [ ${#line} -gt $max_line_width ]; then
                    line="${line:0:$max_line_width}..."
                fi

                if [ -n "$line" ]; then
                    output+="${ANSI_CLEAR_LINE}${ANSI_GRAY}${PADDING_LEFT_SPACES} -> ${line}${ANSI_RESET}\n"
                else
                    output+="${ANSI_CLEAR_LINE}${PADDING_LEFT_SPACES}\n"
                fi
            done

            printf "${ANSI_RESTORE_CURSOR}%b" "$output"

            sleep 0.1
        done
    ) &
    monitor_pid=$!
}

hjarch_stop_log_output() {
    if [ -n "${monitor_pid:-}" ]; then
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true
        unset monitor_pid
    fi
}

hjarch_start_install_log() {
    sudo touch "$JARCH_INSTALL_LOG_FILE"
    sudo chmod 666 "$JARCH_INSTALL_LOG_FILE"

    export JARCH_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    echo "=== J-Arch Installation Started: $JARCH_START_TIME ===" >> "$JARCH_INSTALL_LOG_FILE"
    hjarch_start_log_output "$JARCH_INSTALL_LOG_FILE"
}

hjarch_start_configurator_log() {
    sudo touch "$JARCH_CONFIGURATOR_LOG_FILE"
    sudo chmod 666 "$JARCH_CONFIGURATOR_LOG_FILE"

    echo "=== J-Arch Configurator Started ===" >> "$JARCH_CONFIGURATOR_LOG_FILE"
    hjarch_start_log_output "$JARCH_CONFIGURATOR_LOG_FILE"
}

hjarch_stop_install_log() {
    hjarch_stop_log_output
    hjarch_show_cursor

    if [ -n "${JARCH_INSTALL_LOG_FILE:-}" ]; then
        JARCH_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        echo "=== J-Arch Installation completed: $JARCH_END_TIME ===" >> "$JARCH_INSTALL_LOG_FILE"
        echo "" >> "$JARCH_INSTALL_LOG_FILE"
        echo "=== Installation Time Summary ===" >> "$JARCH_INSTALL_LOG_FILE"

        if [ -f "/var/log/archinstall/install.log" ]; then
            ARCHINSTALL_START=$(grep -m1 '^\[' /var/log/archinstall/install.log 2>/dev/null | sed 's/^\[\([^]]*\)\].*/\1/' || true)
            ARCHINSTALL_END=$(grep 'Installation completed without any errors' /var/log/archinstall/install.log 2>/dev/null | sed 's/^\[\([^]]*\)\].*/\1/' || true)

            if [ -n "$ARCHINSTALL_START" ] && [ -n "$ARCHINSTALL_END" ]; then
                ARCH_START_EPOCH=$(date -d "$ARCHINSTALL_START" +%s)
                ARCH_END_EPOCH=$(date -d "$ARCHINSTALL_END" +%s)
                ARCH_DURATION=$((ARCH_END_EPOCH - ARCH_START_EPOCH))

                ARCH_MINS=$((ARCH_DURATION / 60))
                ARCH_SECS=$((ARCH_DURATION % 60))

                echo "Archinstall: ${ARCH_MINS}m ${ARCH_SECS}s" >>"$JARCH_INSTALL_LOG_FILE"
            fi
        fi

        if [ -n "$JARCH_START_TIME" ]; then
            JARCH_START_EPOCH=$(date -d "$JARCH_START_TIME" +%s)
            JARCH_END_EPOCH=$(date -d "$JARCH_END_TIME" +%s)
            JARCH_DURATION=$((JARCH_END_EPOCH - JARCH_START_EPOCH))

            JARCH_MINS=$((JARCH_DURATION / 60))
            JARCH_SECS=$((JARCH_DURATION % 60))

            echo "J-Arch:     ${JARCH_MINS}m ${JARCH_SECS}s" >>"$JARCH_INSTALL_LOG_FILE"

            if [ -n "$ARCH_DURATION" ]; then
                TOTAL_DURATION=$((ARCH_DURATION + JARCH_DURATION))
                TOTAL_MINS=$((TOTAL_DURATION / 60))
                TOTAL_SECS=$((TOTAL_DURATION % 60))
                echo "Total:       ${TOTAL_MINS}m ${TOTAL_SECS}s" >>"$JARCH_INSTALL_LOG_FILE"
            fi
        fi
        echo "=================================" >>"$JARCH_INSTALL_LOG_FILE"

        echo "Rebooting system..." >>"$JARCH_INSTALL_LOG_FILE"
    fi
}
