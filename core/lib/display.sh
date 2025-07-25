#!/bin/bash

# BashAdminCore - Display and Formatting Module
# Provides color-coded output, formatting utilities, and progress indicators

# Color definitions
declare -g COLOR_RED='\033[0;31m'
declare -g COLOR_GREEN='\033[0;32m'
declare -g COLOR_YELLOW='\033[1;33m'
declare -g COLOR_BLUE='\033[0;34m'
declare -g COLOR_MAGENTA='\033[0;35m'
declare -g COLOR_CYAN='\033[0;36m'
declare -g COLOR_WHITE='\033[1;37m'
declare -g COLOR_GRAY='\033[0;90m'
declare -g COLOR_RESET='\033[0m'

# Bold colors
declare -g COLOR_BOLD_RED='\033[1;31m'
declare -g COLOR_BOLD_GREEN='\033[1;32m'
declare -g COLOR_BOLD_YELLOW='\033[1;33m'
declare -g COLOR_BOLD_BLUE='\033[1;34m'
declare -g COLOR_BOLD_MAGENTA='\033[1;35m'
declare -g COLOR_BOLD_CYAN='\033[1;36m'

# Background colors
declare -g BG_RED='\033[41m'
declare -g BG_GREEN='\033[42m'
declare -g BG_YELLOW='\033[43m'
declare -g BG_BLUE='\033[44m'
declare -g BG_RESET='\033[49m'

# Display settings
declare -g COLOR_OUTPUT_ENABLED=true
declare -g UNICODE_ENABLED=true
declare -g TERMINAL_WIDTH=80

# Initialize display module
init_display() {
    # Check if output is to a terminal
    if [[ -t 1 ]]; then
        COLOR_OUTPUT_ENABLED=true
        # Get terminal width
        TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo 80)
    else
        COLOR_OUTPUT_ENABLED=false
    fi
    
    # Check for color support
    if [[ "${TERM:-dumb}" == "dumb" ]] || [[ "${NO_COLOR:-}" == "true" ]]; then
        COLOR_OUTPUT_ENABLED=false
    fi
    
    # Check for Unicode support
    if [[ "${LANG:-}" =~ UTF-8 ]] || [[ "${LC_ALL:-}" =~ UTF-8 ]]; then
        UNICODE_ENABLED=true
    else
        UNICODE_ENABLED=false
    fi
    
    log_debug "Display initialized (colors: $COLOR_OUTPUT_ENABLED, unicode: $UNICODE_ENABLED, width: $TERMINAL_WIDTH)" "DISPLAY"
}

# Print with color
print_color() {
    local color="$1"
    local message="$2"
    local newline="${3:-true}"
    
    if [[ "$COLOR_OUTPUT_ENABLED" == "true" ]]; then
        echo -en "${color}${message}${COLOR_RESET}"
    else
        echo -en "$message"
    fi
    
    [[ "$newline" == "true" ]] && echo
}

# Status symbols
get_status_symbol() {
    local status="$1"
    
    if [[ "$UNICODE_ENABLED" == "true" ]]; then
        case "$status" in
            success) echo "✓" ;;
            error)   echo "✗" ;;
            warning) echo "⚠" ;;
            info)    echo "ℹ" ;;
            running) echo "▶" ;;
            stopped) echo "■" ;;
            pending) echo "○" ;;
            *)       echo "•" ;;
        esac
    else
        case "$status" in
            success) echo "[OK]" ;;
            error)   echo "[ERROR]" ;;
            warning) echo "[WARN]" ;;
            info)    echo "[INFO]" ;;
            running) echo "[RUN]" ;;
            stopped) echo "[STOP]" ;;
            pending) echo "[PEND]" ;;
            *)       echo "[*]" ;;
        esac
    fi
}

# Print status message
print_status() {
    local status="$1"
    local message="$2"
    local symbol=$(get_status_symbol "$status")
    
    case "$status" in
        success)
            print_color "$COLOR_GREEN" "$symbol $message"
            ;;
        error)
            print_color "$COLOR_RED" "$symbol $message"
            ;;
        warning)
            print_color "$COLOR_YELLOW" "$symbol $message"
            ;;
        info)
            print_color "$COLOR_BLUE" "$symbol $message"
            ;;
        *)
            echo "$symbol $message"
            ;;
    esac
}

# Print header
print_header() {
    local title="$1"
    local style="${2:-single}"  # single, double, thick
    
    local line_char
    case "$style" in
        double) line_char="═" ;;
        thick)  line_char="━" ;;
        *)      line_char="─" ;;
    esac
    
    # Create line
    local line=""
    local title_len=${#title}
    local padding=$(( (TERMINAL_WIDTH - title_len - 2) / 2 ))
    
    if [[ "$UNICODE_ENABLED" == "true" ]]; then
        for ((i=0; i<padding; i++)); do
            line="${line}${line_char}"
        done
        
        print_color "$COLOR_BOLD_CYAN" "${line} ${title} ${line}"
    else
        for ((i=0; i<padding; i++)); do
            line="${line}="
        done
        
        print_color "$COLOR_BOLD_CYAN" "${line} ${title} ${line}"
    fi
}

# Print separator
print_separator() {
    local style="${1:-single}"
    local width="${2:-$TERMINAL_WIDTH}"
    
    local line_char
    case "$style" in
        double) line_char="═" ;;
        thick)  line_char="━" ;;
        dashed) line_char="┅" ;;
        *)      line_char="─" ;;
    esac
    
    local line=""
    if [[ "$UNICODE_ENABLED" == "true" ]]; then
        for ((i=0; i<width; i++)); do
            line="${line}${line_char}"
        done
    else
        for ((i=0; i<width; i++)); do
            line="${line}-"
        done
    fi
    
    print_color "$COLOR_GRAY" "$line"
}

# Print table
print_table() {
    local -n headers=$1
    local -n rows=$2
    local border="${3:-true}"
    
    # Calculate column widths
    local -a col_widths
    for ((i=0; i<${#headers[@]}; i++)); do
        col_widths[$i]=${#headers[$i]}
    done
    
    for row in "${rows[@]}"; do
        IFS='|' read -ra cols <<< "$row"
        for ((i=0; i<${#cols[@]}; i++)); do
            local len=${#cols[$i]}
            [[ $len -gt ${col_widths[$i]} ]] && col_widths[$i]=$len
        done
    done
    
    # Print header
    if [[ "$border" == "true" ]]; then
        print_table_border "${col_widths[@]}"
    fi
    
    # Print headers
    local header_line=""
    for ((i=0; i<${#headers[@]}; i++)); do
        header_line+=$(printf "| %-${col_widths[$i]}s " "${headers[$i]}")
    done
    header_line+="|"
    print_color "$COLOR_BOLD_WHITE" "$header_line"
    
    if [[ "$border" == "true" ]]; then
        print_table_border "${col_widths[@]}"
    fi
    
    # Print rows
    for row in "${rows[@]}"; do
        IFS='|' read -ra cols <<< "$row"
        local row_line=""
        for ((i=0; i<${#cols[@]}; i++)); do
            row_line+=$(printf "| %-${col_widths[$i]}s " "${cols[$i]}")
        done
        row_line+="|"
        echo "$row_line"
    done
    
    if [[ "$border" == "true" ]]; then
        print_table_border "${col_widths[@]}"
    fi
}

# Print table border
print_table_border() {
    local widths=("$@")
    local border="+"
    
    for width in "${widths[@]}"; do
        for ((i=0; i<=width+1; i++)); do
            border+="-"
        done
        border+="+"
    done
    
    echo "$border"
}

# Progress bar
print_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local title="${4:-Progress}"
    
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    # Build progress bar
    local bar="["
    for ((i=0; i<width; i++)); do
        if [[ $i -lt $filled ]]; then
            if [[ "$UNICODE_ENABLED" == "true" ]]; then
                bar+="█"
            else
                bar+="#"
            fi
        else
            if [[ "$UNICODE_ENABLED" == "true" ]]; then
                bar+="░"
            else
                bar+="-"
            fi
        fi
    done
    bar+="]"
    
    # Print progress bar
    printf "\r%-20s %s %3d%% (%d/%d)" "$title" "$bar" "$percent" "$current" "$total"
    
    # New line when complete
    [[ $current -eq $total ]] && echo
}

# Spinner animation
declare -g SPINNER_PID=""
declare -g SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
declare -g SPINNER_FRAME_COUNT=${#SPINNER_FRAMES[@]}

start_spinner() {
    local message="${1:-Working...}"
    
    if [[ "$COLOR_OUTPUT_ENABLED" != "true" ]]; then
        echo "$message"
        return
    fi
    
    # Kill any existing spinner
    stop_spinner
    
    # Start spinner in background
    (
        local i=0
        while true; do
            if [[ "$UNICODE_ENABLED" == "true" ]]; then
                printf "\r${COLOR_CYAN}${SPINNER_FRAMES[$i]}${COLOR_RESET} %s" "$message"
            else
                printf "\r[%s] %s" "-\|/"[$i] "$message"
            fi
            ((i = (i + 1) % SPINNER_FRAME_COUNT))
            sleep 0.1
        done
    ) &
    
    SPINNER_PID=$!
}

stop_spinner() {
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        printf "\r\033[K"  # Clear line
    fi
    SPINNER_PID=""
}

# Print boxed message
print_box() {
    local message="$1"
    local style="${2:-single}"  # single, double, rounded
    
    local lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done <<< "$message"
    
    # Find max line length
    local max_len=0
    for line in "${lines[@]}"; do
        [[ ${#line} -gt $max_len ]] && max_len=${#line}
    done
    
    # Box characters
    local tl tr bl br h v
    if [[ "$UNICODE_ENABLED" == "true" ]]; then
        case "$style" in
            double)
                tl="╔" tr="╗" bl="╚" br="╝" h="═" v="║"
                ;;
            rounded)
                tl="╭" tr="╮" bl="╰" br="╯" h="─" v="│"
                ;;
            *)
                tl="┌" tr="┐" bl="└" br="┘" h="─" v="│"
                ;;
        esac
    else
        tl="+" tr="+" bl="+" br="+" h="-" v="|"
    fi
    
    # Print top border
    echo -n "$tl"
    for ((i=0; i<max_len+2; i++)); do echo -n "$h"; done
    echo "$tr"
    
    # Print lines
    for line in "${lines[@]}"; do
        printf "%s %-${max_len}s %s\n" "$v" "$line" "$v"
    done
    
    # Print bottom border
    echo -n "$bl"
    for ((i=0; i<max_len+2; i++)); do echo -n "$h"; done
    echo "$br"
}

# Print tree structure
print_tree() {
    local path="$1"
    local prefix="${2:-}"
    local is_last="${3:-true}"
    
    local name=$(basename "$path")
    local connector branch
    
    if [[ "$UNICODE_ENABLED" == "true" ]]; then
        connector=$([[ "$is_last" == "true" ]] && echo "└── " || echo "├── ")
        branch=$([[ "$is_last" == "true" ]] && echo "    " || echo "│   ")
    else
        connector=$([[ "$is_last" == "true" ]] && echo "|__ " || echo "|-- ")
        branch=$([[ "$is_last" == "true" ]] && echo "    " || echo "|   ")
    fi
    
    # Print current item
    if [[ -d "$path" ]]; then
        print_color "$COLOR_BLUE" "${prefix}${connector}${name}/"
    else
        echo "${prefix}${connector}${name}"
    fi
    
    # If directory, print contents
    if [[ -d "$path" ]]; then
        local items=()
        while IFS= read -r -d '' item; do
            items+=("$item")
        done < <(find "$path" -maxdepth 1 -mindepth 1 -print0 | sort -z)
        
        local count=${#items[@]}
        local i=0
        for item in "${items[@]}"; do
            ((i++))
            local last=$([[ $i -eq $count ]] && echo "true" || echo "false")
            print_tree "$item" "${prefix}${branch}" "$last"
        done
    fi
}

# Highlight text
highlight() {
    local text="$1"
    local pattern="$2"
    local color="${3:-$COLOR_YELLOW}"
    
    if [[ "$COLOR_OUTPUT_ENABLED" == "true" ]]; then
        echo "$text" | sed "s/${pattern}/${color}&${COLOR_RESET}/g"
    else
        echo "$text"
    fi
}

# Print with indentation
print_indent() {
    local level="$1"
    local message="$2"
    local indent=""
    
    for ((i=0; i<level; i++)); do
        indent+="  "
    done
    
    echo "${indent}${message}"
}

# Format file size
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ $size -ge 1024 ]] && [[ $unit -lt 4 ]]; do
        size=$((size / 1024))
        ((unit++))
    done
    
    echo "${size}${units[$unit]}"
}

# Format duration
format_duration() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    local result=""
    [[ $days -gt 0 ]] && result="${days}d "
    [[ $hours -gt 0 ]] && result="${result}${hours}h "
    [[ $minutes -gt 0 ]] && result="${result}${minutes}m "
    result="${result}${secs}s"
    
    echo "${result# }"
}

# Clear screen with header
clear_screen() {
    local title="${1:-}"
    
    clear
    [[ -n "$title" ]] && print_header "$title"
}

# Wait for user input
wait_for_input() {
    local prompt="${1:-Press any key to continue...}"
    
    print_color "$COLOR_GRAY" "$prompt" false
    read -n 1 -s -r
    echo
}

# Initialize display when sourced
init_display