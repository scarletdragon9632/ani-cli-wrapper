#!/usr/bin/env bash

# ani-cli-wrapper.sh - A user-friendly wrapper for ani-cli with fzf menus
# Author: Based on community needs
# Version: 2.3.0 (with AniList Discovery)

set -euo pipefail

# Configuration
CONFIG_DIR="${HOME}/.config/ani-cli-wrapper"
CONFIG_FILE="${CONFIG_DIR}/config"
CACHE_DIR="${CONFIG_DIR}/cache"
LOG_FILE="${CONFIG_DIR}/ani-wrapper.log"
HISTORY_FILE="${HOME}/.local/state/ani-cli/ani-hsts"
ANILIST_CACHE="${CACHE_DIR}/anilist"

# Color codes for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Default settings
DEFAULT_QUALITY="1080p"
DEFAULT_PLAYER="mpv"
DEFAULT_LANGUAGE="dub"
DOWNLOAD_DIR="${HOME}/Videos/ani-cli"
AUTO_UPDATE=false
SKIP_INTRO=false
AUTO_FALLBACK=true

# Create necessary directories
setup_directories() {
    mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${DOWNLOAD_DIR}" "${ANILIST_CACHE}"
    
    # Create default config if it doesn't exist
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        cat > "${CONFIG_FILE}" << EOF
# ani-cli-wrapper Configuration File
QUALITY="${DEFAULT_QUALITY}"
PLAYER="${DEFAULT_PLAYER}"
LANGUAGE="${DEFAULT_LANGUAGE}"
DOWNLOAD_DIR="${DOWNLOAD_DIR}"
AUTO_UPDATE=false
SKIP_INTRO=false
RECENT_SEARCHES=5
AUTO_FALLBACK=true
HISTORY_FILE="${HOME}/.local/state/ani-cli/ani-hsts"
HEADER_COLOR="CYAN"
CURRENT_HEADER="default.txt"
EOF
    fi
}

# Load configuration
load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
    fi
}

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

# Display header from ASCII art file with selected color
show_header() {
    clear
    
    # Define header directory
    local HEADER_DIR="${CONFIG_DIR}/headers"
    local current_header="${HEADER_DIR}/current.txt"
    
    # Create header directory if it doesn't exist
    mkdir -p "${HEADER_DIR}"
    
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
    ║         ani-cli-wrapper v2.3.0               ║
    ║     Your friendly anime terminal companion   ║
    ║         with AniList Discovery! 🎯           ║
    ╚══════════════════════════════════════════════╝
EOF
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


# Fetch anime from AniList API
fetch_anilist() {
    local query_type="$1"
    local cache_file="${ANILIST_CACHE}/${query_type}.json"
    local cache_age=3600 # 1 hour in seconds
    
    # Check if cache exists and is fresh
    if [[ -f "${cache_file}" ]] && [[ $(($(date +%s) - $(stat -c %Y "${cache_file}" 2>/dev/null || echo 0))) -lt ${cache_age} ]]; then
        cat "${cache_file}"
        return
    fi
    
    local query=""
    case "${query_type}" in
        "trending")
            query='{
              "query": "query { Page(page: 1, perPage: 30) { media(type: ANIME, sort: TRENDING_DESC) { id title { romaji english native } format episodes status description averageScore genres coverImage { large } } } }"
            }'
            ;;
        "popular")
            query='{
              "query": "query { Page(page: 1, perPage: 30) { media(type: ANIME, sort: POPULARITY_DESC) { id title { romaji english native } format episodes status description averageScore genres coverImage { large } } } }"
            }'
            ;;
        "top_rated")
            query='{
              "query": "query { Page(page: 1, perPage: 30) { media(type: ANIME, season: \"'"$season"'\", seasonYear: '"$year"') { id title { romaji english native } format episodes status description averageScore genres coverImage { large } } } }"
            }'
            ;;
        "upcoming")
            query='{
              "query": "query { Page(page: 1, perPage: 30) { media(type: ANIME, status: NOT_YET_RELEASED, sort: POPULARITY_DESC) { id title { romaji english native } format episodes status description averageScore genres coverImage { large } } } }"
            }'
            ;;
    esac
    
    local response=$(curl -s -X POST "https://graphql.anilist.co" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "${query}")
    
    echo "${response}" > "${cache_file}"
    echo "${response}"
}

# Function to fetch and format anime details for preview
fetch_anime_details() {
    local anime_id="$1"
    
    # Skip if no ID
    if [[ -z "${anime_id}" ]]; then
        echo "No anime ID provided"
        return
    fi
    
    # Fetch anime from AniList API
fetch_anilist() {
    local query_type="$1"
    local cache_file="${ANILIST_CACHE}/${query_type}.json"
    local cache_age=3600 # 1 hour in seconds
    
    # Check if cache exists and is fresh
    if [[ -f "${cache_file}" ]] && [[ $(($(date +%s) - $(stat -c %Y "${cache_file}" 2>/dev/null || echo 0))) -lt ${cache_age} ]]; then
        cat "${cache_file}"
        return
    fi
    
    local query=""
    case "${query_type}" in
        "trending")
            query='{"query":"query { Page(page: 1, perPage: 30) { media(type: ANIME, sort: TRENDING_DESC) { id title { romaji english native } format episodes status averageScore genres } } }"}'
            ;;
        "popular")
            query='{"query":"query { Page(page: 1, perPage: 30) { media(type: ANIME, sort: POPULARITY_DESC) { id title { romaji english native } format episodes status averageScore genres } } }"}'
            ;;
        "top_rated")
            query='{"query":"query { Page(page: 1, perPage: 30) { media(type: ANIME, season: '"$season"', seasonYear: '"$year"') { id title { romaji english native } format episodes status averageScore genres } } }"}'
            ;;
        "upcoming")
            query='{"query":"query { Page(page: 1, perPage: 30) { media(type: ANIME, status: NOT_YET_RELEASED, sort: POPULARITY_DESC) { id title { romaji english native } format episodes status averageScore genres } } }"}'
            ;;
    esac
    
    echo -e "${YELLOW}Fetching data from AniList...${NC}" >&2
    local response=$(curl -s -X POST "https://graphql.anilist.co" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "${query}")
    
    # Check if response contains errors
    if echo "${response}" | jq -e '.errors' > /dev/null 2>&1; then
        local error_msg=$(echo "${response}" | jq -r '.errors[0].message // "Unknown error"')
        echo -e "${RED}AniList API Error: ${error_msg}${NC}" >&2
        # If there's an error and cache exists, use cached version
        if [[ -f "${cache_file}" ]]; then
            echo -e "${YELLOW}Using cached data...${NC}" >&2
            cat "${cache_file}"
            return
        fi
    else
        # Save successful response to cache
        echo "${response}" > "${cache_file}"
    fi
    
    echo "${response}"
}
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "jq not installed. Please install jq for details."
        return
    fi
    
    # Parse and format the response
    echo "${response}" | jq -r '
        .data.Media | 
        "╔════════════════════════════════════════════╗",
        "║ " + (.title.english // .title.romaji // .title.native) + " ║",
        "╠════════════════════════════════════════════╣",
        "║ Episodes: " + (.episodes // "?" | tostring),
        "║ Duration: " + (.duration // "?" | tostring) + " min",
        "║ Status: " + (.status // "Unknown"),
        "║ Season: " + (.season // "?") + " " + (.year // "?" | tostring),
        "║ Score: ⭐ " + (.averageScore // "N/A" | tostring),
        "║ Genres: " + (.genres | join(", ")),
        "║ Studios: " + ([.studios.nodes[].name] | join(", ")),
        "╠════════════════════════════════════════════╣",
        "║ Description:",
        "║ " + (.description // "No description" | gsub("<[^>]*>"; "") | gsub("\n"; " ") | .[0:400] + "..."),
        "╚════════════════════════════════════════════╝"
    ' 2>/dev/null || echo "Error loading details"
}

# Parse and display AniList results
show_anilist_results() {
    local query_type="$1"
    local json_data=$(fetch_anilist "${query_type}")
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}jq is required for AniList integration. Please install jq.${NC}"
        echo -e "${YELLOW}Ubuntu/Debian: sudo apt install jq${NC}"
        echo -e "${YELLOW}Arch: sudo pacman -S jq${NC}"
        echo -e "${YELLOW}macOS: brew install jq${NC}"
        sleep 3
        return 1
    fi
    
    # Extract anime list with formatted display
    # Store both English (for display) and Romaji (for search)
    local anime_list=$(echo "${json_data}" | jq -r '.data.Page.media[] | 
        "[\(.id)] " + 
        "DISPLAY: " + (.title.english // .title.romaji // .title.native) + " | " +
        "SEARCH: " + (.title.romaji // .title.english // .title.native) + " | " +
        "⭐ " + (.averageScore // "N/A" | tostring) + 
        " | " + (.format // "TV") + 
        " | " + (.episodes // "?" | tostring) + " eps" + 
        " | " + (.status // "Unknown")' 2>/dev/null)
    
    if [[ -z "${anime_list}" ]]; then
        echo -e "${RED}No results found${NC}"
        return 1
    fi
    
    # Create a temporary file for the preview function
    local preview_script="${CACHE_DIR}/preview.sh"
    cat > "${preview_script}" << 'EOF'
#!/usr/bin/env bash
selected_line="$1"

# Extract ID from format "[123] DISPLAY: ... | SEARCH: ... | ..."
if [[ "$selected_line" =~ \[([0-9]+)\] ]]; then
    id="${BASH_REMATCH[1]}"
    
    # Extract display title (for preview)
    display_title=$(echo "$selected_line" | grep -o "DISPLAY: [^|]*" | sed 's/DISPLAY: //')
    
    # Fetch anime details from AniList
    response=$(curl -s -X POST "https://graphql.anilist.co" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{
            \"query\": \"query { Media(id: $id) { title { romaji english native } description episodes duration status season startDate { year } averageScore genres } }\"
        }")
    
    # Check if response contains data
    if echo "$response" | jq -e '.data.Media' > /dev/null 2>&1; then
        # Extract fields
        title=$(echo "$response" | jq -r '.data.Media.title.english // .data.Media.title.romaji // .data.Media.title.native // "Unknown Title"')
        episodes=$(echo "$response" | jq -r '.data.Media.episodes // "?"')
        duration=$(echo "$response" | jq -r '.data.Media.duration // "?"')
        status=$(echo "$response" | jq -r '.data.Media.status // "Unknown"')
        season=$(echo "$response" | jq -r '.data.Media.season // "?"')
        year=$(echo "$response" | jq -r '.data.Media.startDate.year // "?"')
        score=$(echo "$response" | jq -r '.data.Media.averageScore // "N/A"')
        genres=$(echo "$response" | jq -r '.data.Media.genres // [] | join(", ")')
        
        # Clean description
        description=$(echo "$response" | jq -r '.data.Media.description // "No description available"' | 
            sed -E 's/<[^>]*>//g' |
            sed -E 's/&nbsp;/ /g' |
            sed -E 's/&[a-zA-Z]+;//g' |
            tr '\n' ' ' |
            sed -E 's/\s+/ /g' |
            sed -E 's/^[[:space:]]+|[[:space:]]+$//g' |
            cut -c1-500)
        
        # Calculate box width
        term_width=$(tput cols 2>/dev/null || echo 80)
        box_width=$((term_width - 10))
        [[ $box_width -lt 50 ]] && box_width=50
        [[ $box_width -gt 100 ]] && box_width=100
        
        hr=$(printf '%*s' "$box_width" | tr ' ' '─')
        
        # Display formatted output
        echo "┌${hr}┐"
        printf "│ %-*s \n" $((box_width-2)) "${title:0:$((box_width-2))}"
        echo "├${hr}┤"
        printf "│ Episodes: %-*s \n" $((box_width-12)) "$episodes"
        printf "│ Duration: %-*s \n" $((box_width-12)) "${duration} min"
        printf "│ Status: %-*s \n" $((box_width-10)) "$status"
        printf "│ Season: %-*s \n" $((box_width-10)) "$season $year"
        printf "│ Score: ⭐ %-*s \n" $((box_width-10)) "$score"
        printf "│ Genres: %-*s \n" $((box_width-10)) "${genres:0:$((box_width-10))}"
        echo "├${hr}┤"
        echo "│ Description:"
        echo "$description" | fold -w $((box_width-4)) -s | while IFS= read -r line; do
            printf "│ %-*s \n" $((box_width-2)) "$line"
        done
        echo "└${hr}┘"
    else
        echo "Could not fetch details for ID: $id"
    fi
else
    echo "Select an anime to see details"
fi
EOF
    chmod +x "${preview_script}"
    
    # Use fzf to select anime with preview
    # Extract only the display part for fzf
    local display_list=$(echo "$anime_list" | sed -E 's/ \| SEARCH: [^|]* \|/ \|/g')
    
    local selected=$(echo "${display_list}" | fzf \
        --prompt="Select anime: " \
        --height=30 \
        --border \
        --cycle \
        --preview="${preview_script} {}")
    
    if [[ -n "${selected}" ]]; then
        # Extract ID
        local anime_id=$(echo "${selected}" | grep -o "\[[0-9]*\]" | head -1 | tr -d '[]')
        
        # Get the full line from original anime_list to extract search title
        local full_line=$(echo "$anime_list" | grep "\[${anime_id}\]")
        
        # Extract search title (Romaji) for ani-cli
        local search_title=$(echo "$full_line" | grep -o "SEARCH: [^|]*" | sed 's/SEARCH: //')
        
        # Extract display title (English) for showing to user
        local display_title=$(echo "$selected" | sed -E 's/^\[[0-9]+\] DISPLAY: //;s/ \|.*//')
        
        echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Selected: ${display_title}${NC}"
        echo -e "${YELLOW}Searching with: ${search_title}${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        
        # Ask if user wants to watch
        if fzf_confirm "Watch this anime?"; then
            # Language selection
            local lang_options=(
                "Use configured language (${LANGUAGE})"
                "SUB"
                "DUB"
            )
            
            local lang_choice=$(printf '%s\n' "${lang_options[@]}" | fzf --prompt="Select language: " --height=10)
            
            local preferred_lang="sub"
            case "${lang_choice}" in
                *"DUB"*)
                    preferred_lang="dub"
                    echo -e "${GREEN}Watching DUBBED version${NC}"
                    ;;
                *"SUB"*)
                    preferred_lang="sub"
                    echo -e "${GREEN}Watching SUBBED version${NC}"
                    ;;
                *)
                    if [[ "${LANGUAGE}" == "dub" ]]; then
                        preferred_lang="dub"
                    fi
                    ;;
            esac
            
            # Execute with fallback using search_title (Romaji)
            execute_with_fallback "${search_title}" "${preferred_lang}" "${QUALITY}" "${PLAYER}" "${SKIP_INTRO}"
        fi
    fi
}

# Execute ani-cli with fallback support using fzf
execute_with_fallback() {
    local search_term="$1"
    local preferred_lang="$2"
    local quality="$3"
    local player="$4"
    local skip_intro="$5"
    
    local exit_code=0
    local cmd=""
    
    # Try with preferred language first
    if [[ "${preferred_lang}" == "dub" ]]; then
        echo -e "${GREEN}Trying DUBBED version first...${NC}"
        cmd="ani-cli"
        [[ "${quality}" != "1080p" ]] && cmd+=" -q ${quality}"
        [[ "${player}" == "vlc" ]] && cmd+=" -v"
        cmd+=" --dub"
        [[ "${skip_intro}" == true ]] && cmd+=" --skip --skip-title \"${search_term}\""
        cmd+=" ${search_term}"
        
        echo -e "\n${GREEN}Launching:${NC} ${cmd}"
        
        # Run the command and capture exit code
        set +e
        eval "${cmd}"
        exit_code=$?
        set -e
        
        # Check if failed and fallback is enabled
        if [[ $exit_code -ne 0 ]] && [[ "${AUTO_FALLBACK}" == true ]]; then
            echo -e "\n${YELLOW}DUBBED version not available or failed.${NC}"
            
            # Use fzf for fallback decision
            local fallback_options=(
                "🔄 Try SUBBED version"
                "❌ Cancel"
            )
            
            local fallback_choice=$(printf '%s\n' "${fallback_options[@]}" | fzf --prompt="What would you like to do? " --height=6 --border)
            
            if [[ "${fallback_choice}" == "🔄 Try SUBBED version" ]]; then
                echo -e "\n${GREEN}Trying SUBBED version...${NC}"
                cmd="ani-cli"
                [[ "${quality}" != "1080p" ]] && cmd+=" -q ${quality}"
                [[ "${player}" == "vlc" ]] && cmd+=" -v"
                [[ "${skip_intro}" == true ]] && cmd+=" --skip --skip-title \"${search_term}\""
                cmd+=" ${search_term}"
                
                echo -e "\n${GREEN}Launching:${NC} ${cmd}"
                eval "${cmd}"
            fi
        elif [[ $exit_code -ne 0 ]] && [[ "${AUTO_FALLBACK}" == false ]]; then
            echo -e "\n${YELLOW}DUBBED version failed. Enable auto-fallback in settings for automatic SUB fallback.${NC}"
        fi
    else
        # SUB preferred, try directly
        cmd="ani-cli"
        [[ "${quality}" != "1080p" ]] && cmd+=" -q ${quality}"
        [[ "${player}" == "vlc" ]] && cmd+=" -v"
        [[ "${skip_intro}" == true ]] && cmd+=" --skip --skip-title \"${search_term}\""
        cmd+=" ${search_term}"
        
        echo -e "\n${GREEN}Launching:${NC} ${cmd}"
        eval "${cmd}"
    fi
}

# Search and watch anime with dub option and fallback
search_anime() {
    show_header
    
    # Language selection with fzf
    local lang_options=(
        "Use configured language (${LANGUAGE})"
        "SUB"
        "DUB"
    )
    
    local lang_choice=$(printf '%s\n' "${lang_options[@]}" | fzf --prompt="Select language: " --height=10 --header="Language Preference")
    
    local dub_flag=""
    local lang_display="sub"
    local preferred_lang="sub"
    
    case "${lang_choice}" in
        *"DUB"*)
            dub_flag="--dub"
            lang_display="dub"
            preferred_lang="dub"
            echo -e "${GREEN}Searching for DUBBED anime${NC}"
            ;;
        *"SUB"*)
            dub_flag=""
            lang_display="sub"
            preferred_lang="sub"
            echo -e "${GREEN}Searching for SUBBED anime${NC}"
            ;;
        *)
            if [[ "${LANGUAGE}" == "dub" ]]; then
                dub_flag="--dub"
                lang_display="dub"
                preferred_lang="dub"
                echo -e "${GREEN}Using configured DUB preference${NC}"
            else
                dub_flag=""
                lang_display="sub"
                preferred_lang="sub"
                echo -e "${GREEN}Using configured SUB preference${NC}"
            fi
            ;;
    esac
    
    # Show recent searches
    local search_term=""
    if [[ -f "${CACHE_DIR}/recent_searches" ]] && [[ -s "${CACHE_DIR}/recent_searches" ]]; then
        local recent_options=()
        recent_options+=("🔍 New search")
        while IFS= read -r line; do
            recent_options+=("🕒 ${line}")
        done < <(tail -n "${RECENT_SEARCHES}" "${CACHE_DIR}/recent_searches")
        
        local recent_choice=$(printf '%s\n' "${recent_options[@]}" | fzf --prompt="Search or select recent: " --height=15 --header="Recent Searches")
        
        if [[ "${recent_choice}" != "🔍 New search" ]]; then
            search_term=$(echo "${recent_choice}" | sed 's/^🕒 //')
        fi
    fi
    
    # If no recent selection, ask for new search
    if [[ -z "${search_term}" ]]; then
        echo -e "\n${GREEN}Enter anime name:${NC}"
        echo -e "${YELLOW}Note: Single quotes (') are not supported. Please use Romanji titles without apostrophes.${NC}"
        echo -e "${YELLOW}Example: Use just 'Paradise' search or use Romaji Title 'Jigokuraku' (Recommended) instead of \"Hell's Paradise\"${NC}"
        read -r search_term
    fi
    
    if [[ -z "${search_term}" ]]; then
        echo -e "${RED}Search term cannot be empty${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    # Check for single quotes in search term
    if [[ "${search_term}" == *"'"* ]]; then
        echo -e "\n${RED}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}⚠️  Search Error${NC}"
        echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Single quotes (') are not supported by ani-cli.${NC}"
        echo -e "${YELLOW}Please use Romanji titles without apostrophes.${NC}"
        echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
        echo -e "\n${GREEN}Suggested alternatives:${NC}"
        echo -e "  • ${WHITE}Hell's Paradise${NC} → ${GREEN}Paradise${NC} or ${GREEN}Jigokuraku${NC}"
        echo -e "  • ${WHITE}Hunter x Hunter${NC} → ${GREEN}Hunter x Hunter${NC} (already good)"
        echo -e "  • ${WHITE}Re:Zero${NC} → ${GREEN}Re:Zero${NC} (already good)"
        echo -e "  • ${WHITE}That Time I Got Reincarnated as a Slime${NC} → ${GREEN}That Time I Got Reincarnated as a Slime${NC} (already good)"
        echo -e "\n${YELLOW}Press Enter to try again or 'q' to cancel${NC}"
        
        read -r retry
        if [[ "${retry}" != "q" ]]; then
            search_anime  # Try again
        else
            show_main_menu
        fi
        return
    fi
    
    
    # Save to recent searches
    echo "${search_term}" >> "${CACHE_DIR}/recent_searches"
    tail -n 20 "${CACHE_DIR}/recent_searches" > "${CACHE_DIR}/recent_searches.tmp"
    mv "${CACHE_DIR}/recent_searches.tmp" "${CACHE_DIR}/recent_searches"
    
    # Execute with fallback support
    execute_with_fallback "${search_term}" "${preferred_lang}" "${QUALITY}" "${PLAYER}" "${SKIP_INTRO}"
    
    echo -e "\n${GREEN}Press Enter to continue${NC}"
    read -r
    show_main_menu
}



# Download anime with fzf fallback
download_anime() {
    show_header
    
    # Language selection
    local lang_options=("SUB" "DUB")
    local lang_choice=$(printf '%s\n' "${lang_options[@]}" | fzf --prompt="Select language: " --height=5)
    
    local dub_flag=""
    local preferred_lang="sub"
    if [[ "${lang_choice}" == "DUB" ]]; then
        dub_flag="--dub"
        preferred_lang="dub"
        echo -e "${GREEN}Downloading DUBBED version${NC}"
    else
        echo -e "${GREEN}Downloading SUBBED version${NC}"
    fi
    
    echo -e "\n${GREEN}Enter anime name to download:${NC}"
    read -r download_term
    
    if [[ -z "${download_term}" ]]; then
        echo -e "${RED}Search term cannot be empty${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    
    # Episode selection
    local episode_options=(
        "Select episodes interactively"
        "Single episode"
        "Range (e.g., 1-12)"
        "All episodes"
    )
    
    local ep_choice=$(printf '%s\n' "${episode_options[@]}" | fzf --prompt="Episode selection: " --height=10)
    
    local episode_range=""
    case "${ep_choice}" in
        *"Single"*)
            echo -e "\n${GREEN}Enter episode number:${NC}"
            read -r ep_num
            episode_range="${ep_num}"
            ;;
        *"Range"*)
            echo -e "\n${GREEN}Enter range (e.g., 1-12):${NC}"
            read -r ep_range
            episode_range="${ep_range}"
            ;;
        *"All"*)
            episode_range=""
            ;;
    esac
    
    local cmd="ani-cli -d"
    [[ -n "${episode_range}" ]] && cmd+=" -e ${episode_range}"
    [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
    [[ -n "${dub_flag}" ]] && cmd+=" ${dub_flag}"
    
    cmd+=" \"${download_term}\""
    
    echo -e "\n${GREEN}Downloads will be saved to:${NC} ${DOWNLOAD_DIR}"
    echo -e "${GREEN}Launching:${NC} ${cmd}"
    log "INFO" "Downloading: ${download_term}"
    
    cd "${DOWNLOAD_DIR}"
    set +e
    eval "${cmd}"
    local exit_code=$?
    set -e
    cd - > /dev/null
    
    # Handle download failure with fzf fallback
    if [[ $exit_code -ne 0 ]] && [[ "${preferred_lang}" == "dub" ]] && [[ "${AUTO_FALLBACK}" == true ]]; then
        echo -e "\n${YELLOW}DUBBED download failed.${NC}"
        
        local fallback_options=(
            "🔄 Try SUBBED version"
            "❌ Cancel"
        )
        
        local fallback_choice=$(printf '%s\n' "${fallback_options[@]}" | fzf --prompt="What would you like to do? " --height=6 --border)
        
        if [[ "${fallback_choice}" == "🔄 Try SUBBED version" ]]; then
            echo -e "\n${GREEN}Downloading SUBBED version...${NC}"
            cmd="ani-cli -d"
            [[ -n "${episode_range}" ]] && cmd+=" -e ${episode_range}"
            [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
            cmd+=" \"${download_term}\""
            
            cd "${DOWNLOAD_DIR}"
            eval "${cmd}"
            cd - > /dev/null
        fi
    fi
    
    echo -e "\n${GREEN}Download completed! Files in:${NC} ${DOWNLOAD_DIR}"
    echo -e "\n${GREEN}Press Enter to continue${NC}"
    read -r
    show_main_menu
}

# Main menu with fzf
show_main_menu() {
    show_header
    
    local options=(
        "🔍 Search and Watch Anime"
        "🎯 Continue Watching"
        "📺 Discover Anime (AniList)"
        #"💾 History"
        "📥 Download Anime"
        "⚙️  Settings"
        "📚 My Library/Watchlist"
        "🔄 Check for Updates"
        "❓ Help"
        "🚪 Exit"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select option: " --height=15 --border --cycle)
    
    case "${choice}" in
        *"Search"*) search_anime ;;
        *"Continue"*) continue_watching ;;
        *"Discover"*) discover_anime ;;
        #*"History"*) print_history ;;
        *"Download"*) download_anime ;;
        *"Settings"*) show_settings_menu ;;
        *"Library"*) show_library ;;
        *"Updates"*) check_updates ;;
        *"Help"*) show_help ;;
        *"Exit"*) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) show_main_menu ;;
    esac
}
# Simplified continue watching with direct language toggle
continue_watching() {
    show_header
    
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Continue Watching${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    # Quick language selection
    local options=(
        "▶️  Continue with configured (${LANGUAGE})"
        "▶️  Continue with DUB"
        "▶️  Continue with SUB"
        "❌ Cancel"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select: " --height=8 --border)
    
    local cmd="ani-cli -c"
    
    case "${choice}" in
        *"DUB"*)
            cmd+=" --dub"
            echo -e "${GREEN}Continuing with DUBBED version${NC}"
            ;;
        *"SUB"*)
            # No --dub flag
            echo -e "${GREEN}Continuing with SUBBED version${NC}"
            ;;
        *"configured"*)
            if [[ "${LANGUAGE}" == "dub" ]]; then
                cmd+=" --dub"
                echo -e "${GREEN}Using configured DUB preference${NC}"
            else
                echo -e "${GREEN}Using configured SUB preference${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}Cancelled${NC}"
            sleep 1
            show_main_menu
            return
            ;;
    esac
    
    # Add other options
    [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
    [[ "${PLAYER}" == "vlc" ]] && cmd+=" -v"
    [[ "${SKIP_INTRO}" == true ]] && cmd+=" --skip"
    
    echo -e "\n${GREEN}Launching:${NC} ${cmd}"
    log "INFO" "Continue watching with: ${cmd}"
    
    # Try with selected language
    set +e
    eval "${cmd}"
    local exit_code=$?
    set -e
    
    # If DUB fails and auto-fallback is enabled, offer SUB
    if [[ $exit_code -ne 0 ]] && [[ "${cmd}" == *"--dub"* ]] && [[ "${AUTO_FALLBACK}" == true ]]; then
        echo -e "\n${YELLOW}DUBBED version failed. Try SUBBED?${NC}"
        
        if fzf_confirm "Try SUBBED version?"; then
            local sub_cmd="ani-cli -c"
            [[ "${QUALITY}" != "1080p" ]] && sub_cmd+=" -q ${QUALITY}"
            [[ "${PLAYER}" == "vlc" ]] && sub_cmd+=" -v"
            [[ "${SKIP_INTRO}" == true ]] && cmd+=" --skip"
            
            echo -e "\n${GREEN}Launching SUBBED version...${NC}"
            eval "${sub_cmd}"
        fi
    fi
    
    echo -e "\n${GREEN}Press Enter to return to main menu${NC}"
    read -r
    show_main_menu
}
# Discover anime menu
discover_anime() {
    show_header
    
    local options=(
        "🔥 Trending Now"
        "⭐ Most Popular"
        "🏆 Top Rated"
        "🚀 Upcoming"
        "🔙 Back to Main Menu"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Discover: " --height=10 --border)
    
    case "${choice}" in
        *"Trending"*) show_anilist_results "trending" ;;
        *"Popular"*) show_anilist_results "popular" ;;
        *"Top Rated"*) show_anilist_results "top_rated" ;;
        *"Upcoming"*) show_anilist_results "upcoming" ;;
        *) show_main_menu ;;
    esac
    
    # After selection, return to discover menu
    echo -e "\n${GREEN}Press Enter to continue${NC}"
    read -r
    discover_anime
}
#History menu
# Display history from the txt file with fzf and search
print_history() {
    local history_file="${HISTORY_FILE}"
    
    if [[ ! -f "${history_file}" ]] || [[ ! -s "${history_file}" ]]; then
        echo -e "${YELLOW}No watch history found.${NC}"
        echo -e "\n${GREEN}Press Enter to continue${NC}"
        read -r
        show_main_menu
        return 1
    fi
    
    # Create formatted history entries for fzf
    local history_entries=()
    local history_data=()
    
    while IFS=$'\t' read -r episode_count id title; do
        # Skip empty lines
        [[ -z "${title}" ]] && continue
        
        # Clean up the title (remove episodes count in parentheses if present)
        local clean_title=$(echo "$title" | sed -E 's/\s*\([0-9]+\s*episodes\)\s*$//')
        local total_ep=$(echo "$title" | grep -o '([0-9]\+' | tr -d '(')

        # Create formatted display string
        local display=$(printf "[Ep %s] %s (%s episodes)" "$episode_count" "$clean_title" "$total_ep")
        history_entries+=("${display}")
        history_data+=("${clean_title}|${episode_count}|${id}")
    done < <(tac "${history_file}")  # Show most recent first
    
    if [[ ${#history_entries[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No watch history found.${NC}"
        echo -e "\n${GREEN}Press Enter to continue${NC}"
        read -r
        show_main_menu
        return
    fi
    
    # Add options
    local options=(
        #"🔍 Search History"
        "📊 View Statistics"
        "🗑️  Clear History"
        "🔙 Back to Main Menu"
    )
    
    # Combine history entries with options
    local all_options=("${history_entries[@]}" "${options[@]}")
    
    # Use fzf to select from history or options
    local selected=$(printf '%s\n' "${all_options[@]}" | \
        fzf --prompt="History (type to search): " \
            --height=25 \
            --border \
            --cycle \
            --header="Your Watch History" \
            --preview='
                if [[ {} =~ ^\[Ep\ ([0-9]+)\]\ (.*)$ ]]; then
                    ep="${BASH_REMATCH[1]}"
                    title="${BASH_REMATCH[2]}"
                    t_ep="${BASH_REMATCH[3]}"
                    echo "╔════════════════════════════════════════════╗"
                    echo "║              Anime Details                 ║"
                    echo "╠════════════════════════════════════════════╣"
                    echo "║ Title: $title"
                    echo "║ Episodes: $t_ep"
                    echo "║ Episode(s) Watched: $ep"
                    echo "╚════════════════════════════════════════════╝"
                else
                    echo "Select an option or search for anime"
                fi
            ' \
            --bind 'ctrl-s:change-prompt(Search> )' \
            --bind 'ctrl-c:cancel')
    
    # Handle selection
    if [[ -n "${selected}" ]]; then
        case "${selected}" in
            "🔍 Search History")
                # Interactive search
                echo -e "\n${GREEN}Enter search term:${NC}"
                read -r search_term
                if [[ -n "${search_term}" ]]; then
                    # Search through history
                    local search_results=$(grep -i "${search_term}" "${history_file}" | while IFS=$'\t' read -r ep id title; do
                        clean_title=$(echo "$title" | sed -E 's/\s*\([0-9]+\s*episodes\)\s*$//')
                        echo "[Ep ${ep}] ${clean_title}"
                    done)
                    
                    if [[ -n "${search_results}" ]]; then
                        echo -e "\n${GREEN}Search results for '${search_term}':${NC}"
                        echo "${search_results}" | nl -w3 -s'. ' | while IFS= read -r line; do
                            echo -e "${GREEN}${line}${NC}"
                        done
                        
                        # Allow selection from search results
                        local search_choice=$(echo "${search_results}" | fzf --prompt="Select from results: " --height=15 --border)
                        if [[ -n "${search_choice}" ]]; then
                            # Extract title and episode from selection
                            if [[ "${search_choice}" =~ ^\[Ep\ ([0-9]+)\]\ (.*)$ ]]; then
                                local ep_num="${BASH_REMATCH[1]}"
                                local anime_title="${BASH_REMATCH[2]}"
                                
                                echo -e "\n${GREEN}Selected: ${anime_title} (Episode ${ep_num})${NC}"
                                
                                # Ask if user wants to watch
                                if fzf_confirm "Watch this anime?"; then
                                    # Language selection
                                    local lang_options=(
                                        "Use configured language (${LANGUAGE})"
                                        "SUB"
                                        "DUB"
                                    )
                                    
                                    local lang_choice=$(printf '%s\n' "${lang_options[@]}" | fzf --prompt="Select language: " --height=10)
                                    
                                    local preferred_lang="sub"
                                    local dub_flag=""
                                    case "${lang_choice}" in
                                        *"DUB"*)
                                            preferred_lang="dub"
                                            dub_flag="--dub"
                                            echo -e "${GREEN}Watching DUBBED version${NC}"
                                            ;;
                                        *"SUB"*)
                                            preferred_lang="sub"
                                            dub_flag=""
                                            echo -e "${GREEN}Watching SUBBED version${NC}"
                                            ;;
                                        *)
                                            if [[ "${LANGUAGE}" == "dub" ]]; then
                                                preferred_lang="dub"
                                                dub_flag="--dub"
                                            else
                                                dub_flag=""
                                            fi
                                            ;;
                                    esac
                                    
                                    # Ask how to watch
                                    local watch_options=(
                                        "▶️  Watch episode ${ep_num}"
                                        "📋 Select different episode"
                                        "🔄 Start from beginning"
                                        "❌ Cancel"
                                    )
                                    
                                    local watch_choice=$(printf '%s\n' "${watch_options[@]}" | fzf --prompt="How to watch? " --height=10 --border)
                                    
                                    case "${watch_choice}" in
                                        *"Watch episode ${ep_num}"*)
                                            # Use -e flag with episode number
                                            local cmd="ani-cli -e ${ep_num}"
                                            [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
                                            [[ "${PLAYER}" == "vlc" ]] && cmd+=" -v"
                                            [[ -n "${dub_flag}" ]] && cmd+=" ${dub_flag}"
                                            [[ "${SKIP_INTRO}" == true ]] && cmd+=" --skip --skip-title \"${anime_title}\""
                                            cmd+=" ${anime_title}"
                                            
                                            echo -e "\n${GREEN}Launching:${NC} ${cmd}"
                                            eval "${cmd}"
                                            ;;
                                        *"different episode"*)
                                            echo -e "\n${GREEN}Enter episode number:${NC}"
                                            read -r ep_input
                                            if [[ -n "${ep_input}" ]]; then
                                                local cmd="ani-cli -e ${ep_input}"
                                                [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
                                                [[ "${PLAYER}" == "vlc" ]] && cmd+=" -v"
                                                [[ -n "${dub_flag}" ]] && cmd+=" ${dub_flag}"
                                                [[ "${SKIP_INTRO}" == true ]] && cmd+=" --skip --skip-title \"${anime_title}\""
                                                cmd+=" ${anime_title}"
                                                
                                                echo -e "\n${GREEN}Launching:${NC} ${cmd}"
                                                eval "${cmd}"
                                            fi
                                            ;;
                                        *"beginning"*)
                                            local cmd="ani-cli"
                                            [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
                                            [[ "${PLAYER}" == "vlc" ]] && cmd+=" -v"
                                            [[ -n "${dub_flag}" ]] && cmd+=" ${dub_flag}"
                                            [[ "${SKIP_INTRO}" == true ]] && cmd+=" --skip --skip-title \"${anime_title}\""
                                            cmd+=" ${anime_title}"
                                            
                                            echo -e "\n${GREEN}Launching:${NC} ${cmd}"
                                            eval "${cmd}"
                                            ;;
                                    esac
                                fi
                            fi
                        fi
                    else
                        echo -e "${YELLOW}No matches found for '${search_term}'${NC}"
                    fi
                fi
                ;;
                
            "📊 View Statistics")
                # Show history statistics
                local total_entries=$(wc -l < "${history_file}")
                local unique_anime=$(cut -f3 "${history_file}" | sed -E 's/\s*\([0-9]+\s*episodes\)\s*$//' | sort -u | wc -l)
                local total_episodes=$(awk -F'\t' '{sum += $1} END {print sum}' "${history_file}")
                
                echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
                echo -e "${YELLOW}History Statistics${NC}"
                echo -e "${CYAN}════════════════════════════════════════════${NC}"
                echo -e "${GREEN}Total entries:${NC} ${total_entries}"
                echo -e "${GREEN}Unique anime:${NC} ${unique_anime}"
                echo -e "${GREEN}Total episodes:${NC} ${total_episodes}"
                
                # Most watched anime
                echo -e "\n${YELLOW}Most watched:${NC}"
                cut -f3 "${history_file}" | sed -E 's/\s*\([0-9]+\s*episodes\)\s*$//' | sort | uniq -c | sort -rn | head -5 | while read count name; do
                    echo -e "  ${GREEN}${name}${NC} (${count} times)"
                done
                echo -e "${CYAN}════════════════════════════════════════════${NC}"
                ;;
                
            "🗑️  Clear History")
                if fzf_confirm "Are you sure you want to clear all history?"; then
                    > "${history_file}"
                    echo -e "${GREEN}History cleared!${NC}"
                fi
                ;;
                
            "🔙 Back to Main Menu")
                show_main_menu
                return
                ;;
                
            *)
                # An anime was selected from history
                # Extract title and episode from selection
                if [[ "${selected}" =~ ^\[Ep\ ([0-9]+)\]\ (.*)$ ]]; then
                    local watched_ep="${BASH_REMATCH[1]}"
                    local ep_num="$((BASH_REMATCH[1]+1))"
                    local anime_title="${BASH_REMATCH[2]}"
                    
                    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
                    echo -e "${GREEN}Selected: ${anime_title}${NC}"
                    echo -e "${YELLOW}Last watched: Episode ${watched_ep}${NC}"
                    echo -e "${CYAN}════════════════════════════════════════════${NC}"
                    
                    # Language selection
                    local lang_options=(
                        "Use configured language (${LANGUAGE})"
                        "SUB"
                        "DUB"
                    )
                    
                    local lang_choice=$(printf '%s\n' "${lang_options[@]}" | fzf --prompt="Select language: " --height=10)
                    
                    local preferred_lang="sub"
                    local dub_flag=""
                    case "${lang_choice}" in
                        *"DUB"*)
                            preferred_lang="dub"
                            dub_flag="--dub"
                            echo -e "${GREEN}Watching DUBBED version${NC}"
                            ;;
                        *"SUB"*)
                            preferred_lang="sub"
                            dub_flag=""
                            echo -e "${GREEN}Watching SUBBED version${NC}"
                            ;;
                        *)
                            if [[ "${LANGUAGE}" == "dub" ]]; then
                                preferred_lang="dub"
                                dub_flag="--dub"
                            else
                                dub_flag=""
                            fi
                            ;;
                    esac
                    
                    # Watch options
                    local watch_options=(
                        "▶️  Continue from episode ${ep_num}"
                        "📋 Select different episode"
                        "🔄 Start from beginning"
                        "❌ Cancel"
                    )
                    
                    local watch_choice=$(printf '%s\n' "${watch_options[@]}" | fzf --prompt="How to watch? " --height=10 --border)
                    
                    case "${watch_choice}" in
                        *"Continue from episode ${ep_num}"*)
                            # Use -e flag with episode number from history
                            local cmd="ani-cli -e ${ep_num}"
                            [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
                            [[ "${PLAYER}" == "vlc" ]] && cmd+=" -v"
                            [[ -n "${dub_flag}" ]] && cmd+=" ${dub_flag}"
                            [[ "${SKIP_INTRO}" == true ]] && cmd+=" --skip --skip-title \"${anime_title}\""
                            cmd+=" ${anime_title}"
                            
                            echo -e "\n${GREEN}Launching:${NC} ${cmd}"
                            log "INFO" "Continuing ${anime_title} from episode ${ep_num}"
                            eval "${cmd}"
                            ;;
                        *"different episode"*)
                            echo -e "\n${GREEN}Enter episode number:${NC}"
                            read -r ep_input
                            if [[ -n "${ep_input}" ]]; then
                                local cmd="ani-cli -e ${ep_input}"
                                [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
                                [[ "${PLAYER}" == "vlc" ]] && cmd+=" -v"
                                [[ -n "${dub_flag}" ]] && cmd+=" ${dub_flag}"
                                [[ "${SKIP_INTRO}" == true ]] && cmd+=" --skip --skip-title \"${anime_title}\""
                                cmd+=" ${anime_title}"
                                
                                echo -e "\n${GREEN}Launching:${NC} ${cmd}"
                                eval "${cmd}"
                            fi
                            ;;
                        *"beginning"*)
                            local cmd="ani-cli"
                            [[ "${QUALITY}" != "1080p" ]] && cmd+=" -q ${QUALITY}"
                            [[ "${PLAYER}" == "vlc" ]] && cmd+=" -v"
                            [[ -n "${dub_flag}" ]] && cmd+=" ${dub_flag}"
                            [[ "${SKIP_INTRO}" == true ]] && cmd+=" --skip --skip-title \"${anime_title}\""
                            cmd+=" ${anime_title}"
                            
                            echo -e "\n${GREEN}Launching:${NC} ${cmd}"
                            eval "${cmd}"
                            ;;
                    esac
                fi
                ;;
        esac
    fi
    
    echo -e "\n${GREEN}Press Enter to continue${NC}"
    read -r
    show_main_menu
}


# Settings menu with fzf
show_settings_menu() {
    show_header
    
    while true; do
        local options=(
            "🎬 Quality (current: ${QUALITY})"
            "🎮 Player (current: ${PLAYER})"
            "🔤 Default Language (current: ${LANGUAGE})"
            "🔄 Auto Fallback to SUB (current: ${AUTO_FALLBACK})"
            "📁 Download Directory (current: ${DOWNLOAD_DIR})"
            "📜 History File (current: ${HISTORY_FILE})"
            "🔄 Auto Update (current: ${AUTO_UPDATE})"
            "⏭️  Skip Intro (current: ${SKIP_INTRO})"
            "🎨 Header Art (select ASCII art)"
            "🗑️  Clear Cache/History"
            "🔙 Back to Main Menu"
        )
        
        local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Settings: " --height=18 --border)
        
        case "${choice}" in
            *"Quality"*) change_quality ;;
            *"Player"*) change_player ;;
            *"Language"*) change_language ;;
            *"Auto Fallback"*) toggle_fallback ;;
            *"Download Directory"*) change_download_dir ;;
            *"History File"*) change_history_file ;;
            *"Auto Update"*) toggle_setting "AUTO_UPDATE" ;;
            *"Skip Intro"*) toggle_setting "SKIP_INTRO" ;;
            *"Header Art"*) select_header_art ;;
            *"Clear Cache"*) clear_cache ;;
            *"Back"*) break ;;
        esac
    done
    
    show_main_menu
}

# Toggle auto fallback
toggle_fallback() {
    local options=("✅ Enable" "❌ Disable")
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Auto fallback to SUB when DUB fails: " --height=5 --border)
    
    if [[ "${choice}" == "✅ Enable" ]]; then
        AUTO_FALLBACK=true
        update_config "AUTO_FALLBACK" "true"
        echo -e "${GREEN}Auto fallback enabled${NC}"
    else
        AUTO_FALLBACK=false
        update_config "AUTO_FALLBACK" "false"
        echo -e "${YELLOW}Auto fallback disabled${NC}"
    fi
    sleep 2
}

# Change quality setting
change_quality() {
    local options=("360p" "480p" "720p" "1080p")
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select quality: " --height=10)
    
    if [[ -n "${choice}" ]]; then
        QUALITY="${choice}"
        update_config "QUALITY" "${choice}"
        echo -e "${GREEN}Quality set to ${choice}${NC}"
        sleep 1
    fi
}

# Change player setting
change_player() {
    local options=("mpv" "vlc")
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select player: " --height=5)
    
    if [[ -n "${choice}" ]]; then
        PLAYER="${choice}"
        update_config "PLAYER" "${choice}"
        echo -e "${GREEN}Player set to ${choice}${NC}"
        sleep 1
    fi
}

# Change language setting
change_language() {
    local options=("sub" "dub")
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select default language: " --height=5)
    
    if [[ -n "${choice}" ]]; then
        LANGUAGE="${choice}"
        update_config "LANGUAGE" "${choice}"
        
        echo -e "${GREEN}Default language set to ${choice}${NC}"
        sleep 1
    fi
}


# Change download directory
change_download_dir() {
    echo -e "\n${GREEN}Current download directory:${NC} ${DOWNLOAD_DIR}"
    echo -e "${GREEN}Enter new download directory:${NC}"
    read -r new_dir
    
    if [[ -n "${new_dir}" ]]; then
        if mkdir -p "${new_dir}" 2>/dev/null; then
            DOWNLOAD_DIR="${new_dir}"
            update_config "DOWNLOAD_DIR" "${new_dir}"
            echo -e "${GREEN}Download directory updated${NC}"
        else
            echo -e "${RED}Cannot create directory${NC}"
        fi
        sleep 1
    fi
}
# Simple function to change history file location
change_history_file() {
    echo -e "\n${GREEN}Current history file:${NC} ${HISTORY_FILE}"
    echo -e "${GREEN}Enter new history file path:${NC}"
    echo -e "${YELLOW}Example: /home/user/.local/state/ani-cli/ani-hsts${NC}"
    read -r new_history
    
    if [[ -n "${new_history}" ]]; then
        # Expand tilde if present
        new_history="${new_history/#\~/${HOME}}"
        
        # Create directory if it doesn't exist
        local history_dir=$(dirname "${new_history}")
        if mkdir -p "${history_dir}" 2>/dev/null; then
            # Update the variable
            HISTORY_FILE="${new_history}"
            
            # Update config file
            update_config "HISTORY_FILE" "${new_history}"
            
            # Create empty history file if it doesn't exist
            if [[ ! -f "${HISTORY_FILE}" ]]; then
                touch "${HISTORY_FILE}" 2>/dev/null
                echo -e "${GREEN}Created new history file${NC}"
            fi
            
            echo -e "${GREEN}History file updated to: ${HISTORY_FILE}${NC}"
        else
            echo -e "${RED}Cannot create directory: ${history_dir}${NC}"
        fi
        sleep 2
    fi
}
# Toggle boolean setting
toggle_setting() {
    local setting="$1"
    local current_value="${!setting}"
    
    local options=("✅ Enable" "❌ Disable")
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Toggle ${setting}: " --height=5 --border)
    
    if [[ "${choice}" == "✅ Enable" ]]; then
        eval "${setting}=true"
        update_config "${setting}" "true"
        echo -e "${GREEN}${setting} enabled${NC}"
    else
        eval "${setting}=false"
        update_config "${setting}" "false"
        echo -e "${YELLOW}${setting} disabled${NC}"
    fi
    sleep 1
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

# Clear cache and history
clear_cache() {
    local options=(
        "Clear recent searches only"
        "Clear AniList cache only"
        "Clear watch history"
        "Clear everything"
        "Cancel"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Clear options: " --height=12)
    
    case "${choice}" in
        *"searches only"*)
            rm -f "${CACHE_DIR}/recent_searches"
            echo -e "${GREEN}Recent searches cleared${NC}"
            ;;
        *"AniList cache"*)
            rm -rf "${ANILIST_CACHE}"/*
            echo -e "${GREEN}AniList cache cleared${NC}"
            ;;
        *"watch history"*)
            ani-cli -D 2>/dev/null || true
            echo -e "${GREEN}Watch history cleared${NC}"
            ;;
        *"everything"*)
            rm -f "${CACHE_DIR}/recent_searches"
            rm -rf "${ANILIST_CACHE}"/*
            ani-cli -D 2>/dev/null || true
            echo -e "${GREEN}All caches cleared${NC}"
            ;;
    esac
    sleep 1
}

# Select header ASCII art with color
select_header_art() {
    local header_dir="${CONFIG_DIR}/headers"
    mkdir -p "${header_dir}"
    
    # Create default headers if none exist
    if [[ ! -f "${header_dir}/default.txt" ]]; then
        create_default_header "${header_dir}/default.txt"
    fi
    
    
    # Color selection first
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Select Header Color:${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    local color_options=(
        "🟦 Cyan (current)" 
        "🟩 Green" 
        "🟥 Red" 
        "🟨 Yellow" 
        "🟪 Purple" 
        "⬜ White" 
        "🎨 Custom RGB"
    )
    
    local color_choice=$(printf '%s\n' "${color_options[@]}" | fzf --prompt="Select color: " --height=10 --border)
    
    local selected_color=""
    case "${color_choice}" in
        *"Cyan"*) selected_color="CYAN" ;;
        *"Green"*) selected_color="GREEN" ;;
        *"Red"*) selected_color="RED" ;;
        *"Yellow"*) selected_color="YELLOW" ;;
        *"Purple"*) selected_color="PURPLE" ;;
        *"White"*) selected_color="WHITE" ;;
        *"Custom"*)
            echo -e "\n${GREEN}Enter RGB values (0-255):${NC}"
            echo -e "Red: \c"; read -r r
            echo -e "Green: \c"; read -r g
            echo -e "Blue: \c"; read -r b
            
            # Validate RGB values
            if [[ "$r" =~ ^[0-9]+$ ]] && [[ "$g" =~ ^[0-9]+$ ]] && [[ "$b" =~ ^[0-9]+$ ]] && \
               [ "$r" -ge 0 ] && [ "$r" -le 255 ] && \
               [ "$g" -ge 0 ] && [ "$g" -le 255 ] && \
               [ "$b" -ge 0 ] && [ "$b" -le 255 ]; then
                selected_color="\033[38;2;${r};${g};${b}m"
                # Save RGB values for config
                HEADER_RGB="${r},${g},${b}"
                update_config "HEADER_RGB" "${HEADER_RGB}"
            else
                echo -e "${RED}Invalid RGB values. Using default Cyan.${NC}"
                selected_color="CYAN"
                sleep 2
            fi
            ;;
        *) selected_color="CYAN" ;;
    esac
    
    # Save color preference
    if [[ "$selected_color" != "\033[38;2;"* ]]; then
        update_config "HEADER_COLOR" "${selected_color}"
        HEADER_COLOR="${selected_color}"
    fi
    
    # Now select header file
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Select Header Art:${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    # Get list of header files
    local header_files=()
    while IFS= read -r file; do
        header_files+=("$(basename "${file}")")
    done < <(find "${header_dir}" -name "*.txt" -type f | sort)
    
    if [[ ${#header_files[@]} -eq 0 ]]; then
        echo -e "${RED}No header files found${NC}"
        sleep 2
        return
    fi
    
    # Add options
    local options=("${header_files[@]}" "➕ Add new header" "🎨 Change color" "🔙 Back")
    
    # Preview function with selected color
    local preview_cmd="cat '${header_dir}/{}' 2>/dev/null"
    if [[ "$selected_color" == "\033[38;2;"* ]]; then
        # Custom RGB
        preview_cmd="echo -e \"${selected_color}\$(cat '${header_dir}/{}' 2>/dev/null)${NC}\""
    else
        # Predefined color
        preview_cmd="echo -e \"\${${selected_color}}\$(cat '${header_dir}/{}' 2>/dev/null)${NC}\""
    fi
    
    local selected=$(printf '%s\n' "${options[@]}" | \
        fzf --prompt="Select header art: " \
            --height=50 \
            --border \
            --cycle \
            --preview="${preview_cmd}" \
            --preview-window='right:60%:wrap')
    
    case "${selected}" in
        "➕ Add new header")
            add_new_header
            select_header_art  # Recursive to select color again
            ;;
        "🎨 Change color")
            select_header_art  # Restart color selection
            ;;
        "🔙 Back")
            return
            ;;
        "")
            return
            ;;
        *)
            if [[ -f "${header_dir}/${selected}" ]]; then
                # Save selected header and color
                cp "${header_dir}/${selected}" "${header_dir}/current.txt"
                update_config "CURRENT_HEADER" "${selected}"
                echo -e "\n${GREEN}✓ Header set to: ${selected}${NC}"
                
                # Show preview with selected color
                echo -e "\n${YELLOW}Preview with selected color:${NC}"
                if [[ "$selected_color" == "\033[38;2;"* ]]; then
                    echo -e "${selected_color}"
                    cat "${header_dir}/current.txt"
                    echo -e "${NC}"
                else
                    echo -e "${!selected_color}"
                    cat "${header_dir}/current.txt"
                    echo -e "${NC}"
                fi
                sleep 3
            fi
            ;;
    esac
}
# Add new header art
add_new_header() {
    local header_dir="${CONFIG_DIR}/headers"
    mkdir -p "${header_dir}"
    
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Add New Header Art${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Options:${NC}"
    echo "1. Paste ASCII art directly"
    echo "2. Import from file"
    echo "3. Cancel"
    
    read -r choice
    
    case "${choice}" in
        1)
            echo -e "\n${GREEN}Paste your ASCII art (Ctrl+D to finish):${NC}"
            local temp_file=$(mktemp)
            cat > "${temp_file}"
            
            if [[ -s "${temp_file}" ]]; then
                echo -e "\n${GREEN}Enter name for this header (without .txt):${NC}"
                read -r name
                name="${name:-custom_$(date +%s)}"
                mv "${temp_file}" "${header_dir}/${name}.txt"
                echo -e "${GREEN}✓ Header saved as: ${name}.txt${NC}"
            else
                rm -f "${temp_file}"
                echo -e "${YELLOW}No art provided${NC}"
            fi
            ;;
        2)
            echo -e "\n${GREEN}Enter path to ASCII art file:${NC}"
            read -r file_path
            file_path="${file_path/#\~/${HOME}}"
            
            if [[ -f "${file_path}" ]]; then
                echo -e "\n${GREEN}Enter name for this header (without .txt):${NC}"
                read -r name
                name="${name:-$(basename "${file_path}" .txt)}"
                cp "${file_path}" "${header_dir}/${name}.txt"
                echo -e "${GREEN}✓ Header imported as: ${name}.txt${NC}"
            else
                echo -e "${RED}File not found: ${file_path}${NC}"
            fi
            ;;
       
    esac
    
    sleep 2
}

# Library/Watchlist feature with fzf fallback
show_library() {
    show_header
    
    local watchlist_file="${CONFIG_DIR}/watchlist"
    
    if [[ ! -f "${watchlist_file}" ]]; then
        touch "${watchlist_file}"
    fi
    
    while true; do
        local options=(
            "📖 View/ Watch from watchlist"
            "➕ Add to watchlist"
            "➖ Remove from watchlist"
            "🔙 Back to main menu"
        )
        
        local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Library: " --height=10)
        
        case "${choice}" in
            *"View"*)
                if [[ ! -s "${watchlist_file}" ]]; then
                    echo -e "${YELLOW}Watchlist is empty${NC}"
                    sleep 1
                    continue
                fi
                
                local watch_choice=$(cat "${watchlist_file}" | fzf --prompt="Select to watch: " --height=15)
                if [[ -n "${watch_choice}" ]]; then
                    local anime_name=$(echo "${watch_choice}" | sed 's/ (DUB)//;s/ (SUB)//')
                    
                    
                    if [[ "${watch_choice}" == *"(DUB)"* ]]; then
                        echo -e "${GREEN}Watching DUBBED version${NC}"
                        execute_with_fallback "${anime_name}" "dub" "${QUALITY}" "${PLAYER}" "${SKIP_INTRO}"
                    else
                        echo -e "${GREEN}Watching SUBBED version${NC}"
                        execute_with_fallback "${anime_name}" "sub" "${QUALITY}" "${PLAYER}" "${SKIP_INTRO}"
                    fi
                fi
                ;;
                
            *"Add"*)
                echo -e "\n${GREEN}Enter anime name:${NC}"
                read -r new_anime
                
                if [[ -n "${new_anime}" ]]; then
                    
                    local lang_options=("SUB" "DUB")
                    local lang_choice=$(printf '%s\n' "${lang_options[@]}" | fzf --prompt="Language: " --height=5)
                    
                    if [[ "${lang_choice}" == "DUB" ]]; then
                        echo "${new_anime} (DUB)" >> "${watchlist_file}"
                    else
                        echo "${new_anime} (SUB)" >> "${watchlist_file}"
                    fi
                    echo -e "${GREEN}Added to watchlist${NC}"
                fi
                ;;
                
            *"Remove"*)
                if [[ -s "${watchlist_file}" ]]; then
                    local remove_choice=$(cat "${watchlist_file}" | fzf --prompt="Select to remove: " --height=15 --multi)
                    if [[ -n "${remove_choice}" ]]; then
                        echo "${remove_choice}" | while IFS= read -r line; do
                            sed -i "\|^${line}$|d" "${watchlist_file}"
                        done
                        echo -e "${GREEN}Removed from watchlist${NC}"
                    fi
                else
                    echo -e "${YELLOW}Watchlist is empty${NC}"
                fi
                sleep 1
                ;;
                
            *"Back"*)
                break
                ;;
        esac
    done
    
    show_main_menu
}

# Check for updates
check_updates() {
    show_header
    echo -e "${GREEN}Checking for updates...${NC}\n"
    
    ani-cli -U
    
    echo -e "\n${GREEN}Wrapper version: 2.3.0 (with AniList Discovery)${NC}"
    echo -e "\n${GREEN}Press Enter to continue${NC}"
    read -r
    show_main_menu
}

# Show help
show_help() {
    show_header
    
    cat << EOF | less
    
${GREEN}ani-cli-wrapper v2.3.0 - Help${NC}
${BLUE}═══════════════════════════════════════════════════════════════${NC}

${YELLOW}About:${NC}
  A user-friendly wrapper for ani-cli with fzf-powered menus and AniList integration.

${YELLOW}Features:${NC}
  • 🔍 Search and Watch Anime - Manual search
  • 📺 Discover Anime - Trending, Popular, Top Rated, Upcoming
  • 📥 Download Anime - Batch downloads with episode selection
  • ⚙️  Settings - Persistent configuration
  • 📚 Library - Personal watchlist with language memory

${YELLOW}Keyboard Shortcuts in fzf:${NC}
  • Type to filter/search
  • Ctrl-n / Ctrl-p - Navigate up/down
  • Enter - Select
  • Esc / Ctrl-c - Cancel
  • Tab - Multi-select (where applicable)
  • ? - Toggle preview window

${YELLOW}Configuration:${NC}
  • File: ${CONFIG_FILE}
  • Cache: ${CACHE_DIR}
  • Downloads: ${DOWNLOAD_DIR}

${BLUE}═══════════════════════════════════════════════════════════════${NC}
Press 'q' to exit help
EOF
    
    show_main_menu
}

# Cleanup on exit
cleanup() {
    echo -e "\n${GREEN}Goodbye!${NC}"
    log "INFO" "Session ended"
    exit 0
}

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
    
    log "INFO" "Session started (v2.3.0 with AniList Discovery)"
    
    # Auto-update if enabled
    if [[ "${AUTO_UPDATE}" == true ]]; then
        ani-cli -U &> /dev/null || true
    fi
    
    show_main_menu
}

# Run main function
main "$@"  
