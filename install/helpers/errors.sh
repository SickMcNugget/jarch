# Track if we're already handling an error to prevent double trapping
ERROR_HANDLING=false

hjarch_show_cursor() {
    printf "\033[?25h"
}

# Display truncated log lines from the install log
hjarch_show_log_tail() {
    if [ -f "$JARCH_INSTALL_LOG_FILE" ]; then
        local log_lines=$(($TERM_HEIGHT - $LOGO_HEIGHT - 35))
        local max_line_width=$((LOGO_WIDTH - 4))

        tail -n $log_lines "$JARCH_INSTALL_LOG_FILE" | while IFS= read -r line; do
            if ((${#line} > max_line_width)); then
                local truncated_line="${line:0:$max_line_width}..."
            else
                local truncated_line="$line"
            fi

            gum style "$truncated_line"
        done

    echo
    fi
}

hjarch_show_failed_script_or_command() {
    if [ -n "${CURRENT_SCRIPT:-}" ]; then
        gum style "Failed script: $CURRENT_SCRIPT"
    else
        local cmd="$BASH_COMMAND"
        local max_cmd_width=$((LOGO_WIDTH - 4))

        if ((${#cmd} > max_cmd_width)); then
            cmd="${cmd:0:$max_cmd_width}..."
        fi

        gum style "$cmd"
    fi
}

hjarch_save_original_outputs() {
    exec 3>&1 4>&2
}

hjarch_restore_outputs() {
    if [ -e /proc/self/fd/3 ] && [ -e /proc/self/fd/4 ]; then
        exec 1>&3 2>&4
    fi
}

# Main error handler
hjarch_catch_errors() {
    # Prevent recursive errors
    if $ERROR_HANDLING; then
        return
    else
        ERROR_HANDLING=true
    fi

    local exit_code=$?

    hjarch_stop_log_output
    hjarch_restore_outputs

    hjarch_clear_logo
    hjarch_show_cursor

    gum style --foreground 1 --padding "1 0 1 $PADDING_LEFT" "J-Arch installation stopped!"
    hjarch_show_log_tail

    gum style "This command halted with exit code $exit_code:"
    hjarch_show_failed_script_or_command

    # Options menu
    while true; do
        options=()
        if [ -n "${JARCH_ONLINE_INSTALL:-}" ]; then
            options+=("Retry installation")
        fi

        options+=("View full log")
        options+=("Exit")

        choice=$(gum choose "${options[@]}" --header "What would you like to do?" --height 6 --padding "1 $PADDING_LEFT")

        case "$choice" in
            "Retry installation")
                bash ~/.local/share/jarch/install.sh
                break
                ;;
            "View full log")
                if command -v less &>/dev/null; then
                    less "$JARCH_INSTALL_LOG_FILE"
                else
                    tail "$JARCH_INSTALL_LOG_FILE"
                fi
                ;;
            "Exit" | "")
                exit 1
                ;;
        esac
    done
}

# Ensures cleanup happens on exit
hjarch_exit_handler() {
    local exit_code=$?

    if [[ $exit_code -ne 0 && $ERROR_HANDLING != true ]]; then
        hjarch_catch_errors
    else
        hjarch_stop_log_output
        hjarch_show_cursor
    fi
}

trap hjarch_catch_errors ERR INT TERM
trap hjarch_exit_handler EXIT

hjarch_save_original_outputs
