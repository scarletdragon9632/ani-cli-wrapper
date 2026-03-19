#!/usr/bin/env bash

# UI functions (colors, headers, fzf)

# Color codes for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

export RED GREEN YELLOW BLUE PURPLE CYAN WHITE NC

show_header() {
    clear

    local current_header="${HEADER_DIR}/current.txt"
    
    # If current header doesn't exist, create default
    if [[ ! -f "${current_header}" ]]; then
        create_default_header "${current_header}"
    fi
    
    # Get color from config
    local header_color="${HEADER_COLOR:-CYAN}"
    local header_rgb="${HEADER_RGB:-}"
    
     # Display the header with selected color
    if [[ -n "${header_rgb}" ]]; then
        # Custom RGB color
        IFS=',' read -r r g b <<< "${header_rgb}"
        echo -e "\033[38;2;${r};${g};${b}m"
        cat "${current_header}" 2>/dev/null || {
            create_default_header "${current_header}"
            cat "${current_header}"
        }
        echo -e "${NC}"
    else
        # Predefined color
        case "${header_color}" in
            "RED") echo -e "${RED}" ;;
            "GREEN") echo -e "${GREEN}" ;;
            "YELLOW") echo -e "${YELLOW}" ;;
            "BLUE") echo -e "${BLUE}" ;;
            "PURPLE") echo -e "${PURPLE}" ;;
            "CYAN") echo -e "${CYAN}" ;;
            "WHITE") echo -e "${WHITE}" ;;
            *) echo -e "${CYAN}" ;;
        esac
        cat "${current_header}" 2>/dev/null || {
            create_default_header "${current_header}"
            cat "${current_header}"
        }
        echo -e "${NC}"
    fi
        
   
}

# Create default header file
create_default_header() {
    local output_file="$1"
    
    cat > "${output_file}" << 'EOF'
    ╔══════════════════════════════════════════════╗
    ║             ani-cli-wrapper                  ║
    ║     Your friendly anime terminal companion   ║
    ║         with AniList Discovery! 🎯           ║
    ╚══════════════════════════════════════════════╝
EOF
}

# FZF selector function
fzf_select() {
    local prompt="$1"
    shift
    local options=("$@")
    printf '%s\n' "${options[@]}" | fzf --prompt="${prompt} " --height=15 --border --cycle
}

# FZF yes/no selector
fzf_confirm() {
    local prompt="$1"
    local options=("✅ Yes" "❌ No")
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="${prompt} " --height=6 --border)
    
    if [[ "${choice}" == "✅ Yes" ]]; then
        return 0
    else
        return 1
    fi
}