#!/usr/bin/env bash

# ani-cli-wrapper - Main entry point
# Version: 2.3.0

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source all modules
source "${LIB_DIR}/core.sh"         # Must be first
source "${LIB_DIR}/ui.sh"           # UI functions
source "${LIB_DIR}/anime.sh"        # Anime search/playback
source "${LIB_DIR}/anilist.sh"      # AniList integration
source "${LIB_DIR}/download.sh"     # Download functions
source "${LIB_DIR}/history.sh"      # History management
source "${LIB_DIR}/library.sh"      # Watchlist/library
source "${LIB_DIR}/settings.sh"     # Settings menu
source "${LIB_DIR}/update.sh"       # Update functions
source "${LIB_DIR}/anilist_user.sh" # AniList user menu

# Parse command line arguments
parse_arguments "$@"

# Main execution
main() {
    trap cleanup SIGINT SIGTERM
    
    setup_directories
    load_config
    check_dependencies
    
    # Check for jq (optional but recommended)
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq not found. Install for better AniList integration.${NC}"
        echo -e "${YELLOW}Ubuntu/Debian: sudo apt install jq${NC}"
        echo -e "${YELLOW}Arch: sudo pacman -S jq${NC}"
        echo -e "${YELLOW}macOS: brew install jq${NC}"
        sleep 3
    fi
    
    log "INFO" "Session started (v2.3.0)"
    show_main_menu
}

# Run main function
main "$@"