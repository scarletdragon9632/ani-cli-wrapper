#!/usr/bin/env bash

# Core configuration and utility functions

# Configuration
CONFIG_DIR="${HOME}/.config/ani-cli-wrapper"
CONFIG_FILE="${CONFIG_DIR}/config"
CACHE_DIR="${CONFIG_DIR}/cache"
LOG_FILE="${CONFIG_DIR}/ani-wrapper.log"
HISTORY_FILE="${HOME}/.local/state/ani-cli/ani-hsts"
ANILIST_CACHE="${CACHE_DIR}/anilist"
HEADER_DIR="${CONFIG_DIR}/headers"

# Default settings
DEFAULT_QUALITY="1080p"
DEFAULT_PLAYER="mpv"
DEFAULT_LANGUAGE="dub"
DOWNLOAD_DIR="${HOME}/Videos/ani-cli"
SKIP_INTRO=false
AUTO_FALLBACK=true
HEADER_COLOR="CYAN"
CURRENT_HEADER="default.txt"
CURRENT_VERSION="1.7.0"
ENGLISH_TITLE=true

# Export variables
export CONFIG_DIR CONFIG_FILE CACHE_DIR LOG_FILE HISTORY_FILE
export ANILIST_CACHE
export DEFAULT_QUALITY DEFAULT_PLAYER DEFAULT_LANGUAGE
export DOWNLOAD_DIR HEADER_DIR SKIP_INTRO DUB_SEARCH AUTO_FALLBACK

# Create necessary directories
setup_directories() {
    mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${DOWNLOAD_DIR}" "${ANILIST_CACHE}"
    
    # Create default config if it doesn't exist
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        cat > "${CONFIG_FILE}" << EOF
# ani-cli-wrapper Configuration File
CURRENT_VERSION="1.7.0"
QUALITY="${DEFAULT_QUALITY}"
PLAYER="${DEFAULT_PLAYER}"
LANGUAGE="${DEFAULT_LANGUAGE}"
DOWNLOAD_DIR="${DOWNLOAD_DIR}"
SKIP_INTRO=false
RECENT_SEARCHES=5
AUTO_FALLBACK=true
HISTORY_FILE="${HOME}/.local/state/ani-cli/ani-hsts"
HEADER_COLOR="CYAN"
CURRENT_HEADER="default.txt"
ANIME_TITLE=true
EOF
    fi
}

# Create header directory if it doesn't exist
    mkdir -p "${HEADER_DIR}"
    

# Load configuration
load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
    fi

    # Set defaults if not defined
    QUALITY="${QUALITY:-$DEFAULT_QUALITY}"
    PLAYER="${PLAYER:-$DEFAULT_PLAYER}"
    LANGUAGE="${LANGUAGE:-$DEFAULT_LANGUAGE}"
    DOWNLOAD_DIR="${DOWNLOAD_DIR:-$HOME/Videos/ani-cli}"
    SAVE_HISTORY="${SAVE_HISTORY:-true}"
    AUTO_UPDATE="${AUTO_UPDATE:-false}"
    SKIP_INTRO="${SKIP_INTRO:-false}"
    DUB_SEARCH="${DUB_SEARCH:-false}"
    AUTO_FALLBACK="${AUTO_FALLBACK:-true}"
    RECENT_SEARCHES="${RECENT_SEARCHES:-5}"
    HISTORY_FILE="${HISTORY_FILE:-$HOME/.local/state/ani-cli/ani-hsts}"
    HEADER_COLOR="${HEADER_COLOR:-CYAN}"
}

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

# Update config file
update_config() {
    local key="$1"
    local value="$2"
    
    export "${key}=${value}"
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        sed -i "s/^${key}=.*/${key}=${value}/" "${CONFIG_FILE}"
    fi
    log "INFO" "Config updated: ${key}=${value}"
}

# Cleanup on exit
cleanup() {
    echo -e "\n${GREEN}Goodbye!${NC}"
    log "INFO" "Session ended"
    exit 0
}

# Check dependencies
check_dependencies() {
    local deps=("ani-cli" "fzf" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing+=("${dep}")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Missing dependencies: ${missing[*]}${NC}"
        echo -e "${YELLOW}Please install them first:${NC}"
        echo "  - ani-cli: https://github.com/pystardust/ani-cli"
        echo "  - fzf: Use your package manager"
        exit 1
    fi
}

# Main menu with fzf
show_main_menu() {
    show_header
    
    local options=(
        "🔍 Search and Watch Anime"
        "🎯 Continue Watching"
        "📺 Discover Anime (AniList)"
        "👤 My AniList Profile/Library"
        "📥 Download Anime"
        "⚙️  Settings"
        "💾 History"
        #"🔄 Check for Updates"
        "❓ Help"
        "🚪 Exit"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select option: " --height=15 --border --cycle)
    
    case "${choice}" in
        *"Search"*) search_anime ;;
        *"Continue"*) continue_watching ;;
        *"Discover"*) discover_anime ;;
        *"My AniList"*) anilist_user_menu ;;
        *"Download"*) download_anime ;;
        *"Settings"*) show_settings_menu ;;
        *"History"*) print_history ;;
        *"Updates"*) check_updates ;;
        *"Help"*) show_help ;;
        *"Exit"*) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) show_main_menu ;;
    esac
}


# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--search) quick_search "$2"; shift 2 ;;
            -d|--download) quick_download "$2"; shift 2 ;;
            -l|--library) show_library ;;
            --debug) DEBUG=true; shift ;;
            --version) echo "ani-wrapper v2.3.0"; exit 0 ;;
            --update) quick_update; exit 0 ;;
            --update-wrapper) update_ani_cli_wrapper; exit 0 ;;
            --update-ani) update_ani_cli; exit 0 ;;
            --check-versions) check_versions; exit 0 ;;
            --help) show_quick_help; exit 0 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done
}