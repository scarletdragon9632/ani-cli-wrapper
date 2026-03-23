#!/usr/bin/env bash

# AniList User Module
# Handles user authentication, library management, and personal lists
# Dependencies: curl, jq, fzf

# ==============================================
# CONFIGURATION
# ==============================================

ANILIST_API="https://graphql.anilist.co"
ANILIST_AUTH_URL="https://anilist.co/api/v2/oauth/authorize?client_id=9857&response_type=token"
CLIENT_ID="9857"
DATA_DIR="${CONFIG_DIR}/anilist"
TOKEN_FILE="${DATA_DIR}/token.txt"
USER_ID_FILE="${DATA_DIR}/user_id.txt"
USER_CACHE="${DATA_DIR}/user_cache.json"
LIBRARY_CACHE="${DATA_DIR}/library_cache.json"

# ==============================================
# INITIALIZATION
# ==============================================

init_anilist_user() {
    mkdir -p "${DATA_DIR}"
    
    # Load token if exists
    if [[ -f "${TOKEN_FILE}" ]]; then
        ANILIST_TOKEN=$(cat "${TOKEN_FILE}")
    fi
    
    # Load user ID if exists
    if [[ -f "${USER_ID_FILE}" ]]; then
        ANILIST_USER_ID=$(cat "${USER_ID_FILE}")
    fi
}

# ==============================================
# AUTHENTICATION
# ==============================================

# Check and refresh credentials
check_credentials() {
    # Load existing token - use default empty if not set
    local token=""
    if [[ -f "${TOKEN_FILE}" ]]; then
        token=$(cat "${TOKEN_FILE}")
        ANILIST_TOKEN="${token}"
    fi
    
    # If no token, get one
    if [[ -z "${ANILIST_TOKEN:-}" ]]; then
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}AniList Authentication Required${NC}"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        echo -e "1. Visit this URL to get your token:"
        echo -e "${GREEN}${ANILIST_AUTH_URL}${NC}"
        echo -e "\n2. After authorizing, you'll be redirected to a page that looks like:"
        echo -e "${BLUE}https://anilist.co/api/v2/oauth/authorize#access_token=YOUR_TOKEN${NC}"
        echo -e "\n3. ${YELLOW}Copy the Anilist Access Token from your browser${NC}"
        echo -e "\n${GREEN}Paste the Access Token here:${NC}"
        read -r auth_response
        
        ANILIST_TOKEN="${auth_response}"
        
        if [[ -n "${ANILIST_TOKEN:-}" ]]; then
            echo "${ANILIST_TOKEN}" > "${TOKEN_FILE}"
            chmod 600 "${TOKEN_FILE}"
            echo -e "${GREEN}✓ Token saved successfully${NC}"
        else
            echo -e "${RED}✗ Failed to extract token${NC}"
            return 1
        fi
    fi
    
    # Get user ID if not present
    if [[ -z "${ANILIST_USER_ID:-}" ]]; then
        if [[ -f "${USER_ID_FILE}" ]]; then
            ANILIST_USER_ID=$(cat "${USER_ID_FILE}")
        fi
    fi
    
    if [[ -z "${ANILIST_USER_ID:-}" ]]; then
        echo -e "\n${YELLOW}Fetching user information...${NC}"
        
        local query='{"query":"query { Viewer { id name } }"}'
        local response=$(curl -s -X POST "${ANILIST_API}" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: Bearer ${ANILIST_TOKEN}" \
            -d "${query}")
        
        ANILIST_USER_ID=$(echo "${response}" | jq -r '.data.Viewer.id // ""')
        
        if [[ -n "${ANILIST_USER_ID:-}" ]]; then
            echo "${ANILIST_USER_ID}" > "${USER_ID_FILE}"
            local user_name=$(echo "${response}" | jq -r '.data.Viewer.name')
            echo -e "${GREEN}✓ Logged in as: ${user_name}${NC}"
            echo "${response}" > "${USER_CACHE}"
        else
            echo -e "${RED}✗ Failed to get user ID${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Exchange code for token (if needed)
exchange_code_for_token() {
    local code="$1"
    # This would require client secret - not implemented
    echo ""
}

# ==============================================
# USER INFORMATION
# ==============================================

# Display user profile
show_user_profile() {
    check_credentials || return 1
    
    
    local query='{"query":"query { Viewer { id name avatar { large } options { titleLanguage profileColor } statistics { anime { count episodesWatched minutesWatched meanScore } } } }"}'
    local response=$(curl -s -X POST "${ANILIST_API}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ANILIST_TOKEN}" \
        -d "${query}")
    
    if echo "${response}" | jq -e '.data.Viewer' > /dev/null 2>&1; then
        local name=$(echo "${response}" | jq -r '.data.Viewer.name')
        local anime_count=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.count // 0')
        local episodes=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.episodesWatched // 0')
        local minutes=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.minutesWatched // 0')
        local mean_score=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.meanScore // 0')
        
        # Calculate days watched
        local days=$((minutes / 1440))
        local hours=$(((minutes % 1440) / 60))
        
        echo -e "${GREEN}Username:${NC} ${name}"
        echo -e "${GREEN}Anime Watched:${NC} ${anime_count}"
        echo -e "${GREEN}Episodes:${NC} ${episodes}"
        echo -e "${GREEN}Time Watched:${NC} ${days}d ${hours}h"
        echo -e "${GREEN}Mean Score:${NC} ⭐ ${mean_score}"
    else
        echo -e "${RED}Failed to fetch profile${NC}"
    fi
}

# ==============================================
# LIBRARY MANAGEMENT
# ==============================================

# Fetch user's anime list
fetch_user_library() {
    local user_id="${1:-${ANILIST_USER_ID}}"
    local status="${2:-ALL}"
    local force_refresh="${3:-false}"
    
    local cache_file="${LIBRARY_CACHE}.${status}"
    
    # Check cache (valid for 1 hour)
    if [[ "${force_refresh}" != "true" ]] && [[ -f "${cache_file}" ]] && [[ $(($(date +%s) - $(stat -c %Y "${cache_file}" 2>/dev/null || echo 0))) -lt 3600 ]]; then
        cat "${cache_file}"
        return 0
    fi
    
    check_credentials || return 1
    
    local status_filter=""
    if [[ "${status}" != "ALL" ]]; then
        status_filter=", status: ${status}"
    fi
    
    local query='{"query":"query ($userId: Int) { MediaListCollection(userId: $userId, type: ANIME'${status_filter}') { lists { name entries { id mediaId status score progress media { id title { romaji english native } episodes format status averageScore coverImage { large } startDate { year } } } } } }","variables":{"userId":'"${user_id}"'}}'
    
    local response=$(curl -s -X POST "${ANILIST_API}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ANILIST_TOKEN}" \
        -d "${query}")
    
    # Check for curl errors
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Network error: Failed to connect to AniList${NC}" >&2
        return 1
    fi
    
    # Validate JSON
    if ! echo "${response}" | jq empty 2>/dev/null; then
        echo -e "${RED}Invalid JSON response${NC}" >&2
        return 1
    fi
    
    # Check for API errors
    if echo "${response}" | jq -e '.errors' > /dev/null 2>&1; then
        local error_msg=$(echo "${response}" | jq -r '.errors[0].message // "Unknown error"')
        echo -e "${RED}API Error: ${error_msg}${NC}" >&2
        return 1
    fi
    
    # Check if we got data
    if ! echo "${response}" | jq -e '.data.MediaListCollection' > /dev/null 2>&1; then
        echo -e "${YELLOW}No library data found${NC}" >&2
        return 1
    fi
    
    # Cache successful response
    echo "${response}" > "${cache_file}"
    echo "${response}"
    return 0
}
# Display user library
show_user_library() {
    check_credentials || return 1
    
    local status_options=(
        "📺 Currently Watching"
        "📋 Planning to Watch"
        "✅ Completed"
        "⏸️ Paused"
        "🔄 Rewatching"
        "🗑️ Dropped"
        "📚 All Lists"
        "🔄 Sync Library Now"  # Add this option
        "🔙 Back"
    )
    
    while true; do
        local choice=$(printf '%s\n' "${status_options[@]}" | fzf --prompt="Select list: " --height=12 --border)
        
        case "${choice}" in
            *"Currently"*) status_filter="CURRENT" ;;
            *"Planning"*) status_filter="PLANNING" ;;
            *"Completed"*) status_filter="COMPLETED" ;;
            *"Paused"*) status_filter="PAUSED" ;;
            *"Rewatching"*) status_filter="REPEATING" ;;
            *"Dropped"*) status_filter="DROPPED" ;;
            *"All"*) status_filter="ALL" ;;
            *"Sync"*) 
                sync_library
                continue
                ;;
            *) break ;;
        esac
        
        display_library_list "${status_filter}"
    done
}
# Display specific library list
display_library_list() {
    local status="$1"
    local response=$(fetch_user_library "${ANILIST_USER_ID}" "${status}")
    
    if [[ -z "${response}" ]]; then
        echo -e "\n${YELLOW}No data returned. Please try syncing your library.${NC}"
        sleep 2
        return
    fi
    
    # Check if response contains valid JSON
    if ! echo "${response}" | jq empty 2>/dev/null; then
        echo -e "\n${RED}Invalid response from server${NC}"
        sleep 2
        return
    fi
    
    # Build selection list
    local entries=$(echo "${response}" | jq -r '.data.MediaListCollection.lists[]?.entries[]? | 
        "[\(.mediaId)] " + 
        (.media.title.english // .media.title.romaji // .media.title.native) + 
        " | Progress: 📈 " + (.progress | tostring) + "/" + (.media.episodes // "?" | tostring) + 
        " | Score: ⭐ " + (.score // "0" | tostring) +
        " | Status: " + .status' 2>/dev/null)
    
    if [[ -z "${entries}" ]]; then
        echo -e "\n${YELLOW}No entries in this list${NC}"
        echo -e "${YELLOW}Try adding some anime to your list first!${NC}"
        sleep 2
        return
    fi
    
    # Preview script for library items
    local preview_script="${CACHE_DIR}/library_preview.sh"
    create_library_preview_script "${preview_script}"
    
    local selected=$(echo "${entries}" | fzf \
        --prompt="Select anime: " \
        --height=40 \
        --border \
        --preview="${preview_script} {}" \
        --preview-window='right:30%')
    
    if [[ -n "${selected}" ]]; then
        local anime_id=$(echo "${selected}" | grep -o "\[[0-9]*\]" | tr -d '[]')
        local anime_name=$(echo "${selected}" | sed -E 's/^\[[0-9]+\] //;s/ \|.*//')
        
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Selected: ${anime_name}${NC}"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        
        local action_options=(
            "▶️ Watch Now"
            "📊 Update Progress"
            "⭐ Update Score"
            "📝 Update Status"
            "❌ Remove from List"
            "🔙 Back"
        )
        
        local action=$(printf '%s\n' "${action_options[@]}" | fzf --prompt="Action: " --height=8 --border)
        
        case "${action}" in
            *"Watch"*)
                # Get language preference
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
                
                execute_with_fallback "${anime_name}" "${preferred_lang}" "${QUALITY}" "${PLAYER}" "${SKIP_INTRO}"
                ;;
            *"Progress"*)
                update_anime_progress "${anime_id}" "${anime_name}"
                # Refresh the list after update
                display_library_list "${status}"
                return
                ;;
            *"Score"*)
                update_anime_score "${anime_id}" "${anime_name}"
                # Refresh the list after update
                display_library_list "${status}"
                return
                ;;
            *"Status"*)
                update_anime_status "${anime_id}" "${anime_name}"
                # Refresh the list after update
                display_library_list "${status}"
                return
                ;;
            *"Remove"*)
                remove_from_library "${anime_id}" "${anime_name}"
                # Refresh the list after removal
                display_library_list "${status}"
                return
                ;;
        esac
    fi
}
# Create library preview script with embedded token and user ID
create_library_preview_script() {
    local script="$1"
    local token="${ANILIST_TOKEN}"
    local user_id="${ANILIST_USER_ID}"
    
    cat > "${script}" << EOF
#!/usr/bin/env bash
selected="\$1"

# Extract ID
id=""
if [[ "\$selected" =~ \[([0-9]+)\] ]]; then
    id="\${BASH_REMATCH[1]}"
fi

if [[ -z "\$id" ]]; then
    echo "Select an anime to see details"
    exit 0
fi

# Build the query as a single string
query='{"query":"query { Media(id: '"\$id"') { title { romaji english native } episodes status averageScore coverImage { extraLarge large medium } } MediaList(userId: ${user_id}, mediaId: '"\$id"') { progress status score } }"}'

# Make the API request
response=\$(curl -s -X POST "https://graphql.anilist.co" \\
    -H "Content-Type: application/json" \\
    -H "Authorization: Bearer ${token}" \\
    -d "\$query")

# Extract image URL and show it with chafa if available
image_url=\$(echo "\$response" | jq -r '.data.Media.coverImage.extraLarge // .data.Media.coverImage.large // .data.Media.coverImage.medium // ""')

if [[ -n "\$image_url" ]] && command -v chafa &> /dev/null; then
    img_temp="/tmp/anime_preview_\${id}.jpg"
    curl -s -L "\$image_url" -o "\$img_temp" 2>/dev/null
    
    if [[ -f "\$img_temp" ]]; then
        term_width=\$(tput cols 2>/dev/null || echo 80)
        term_height=\$(tput lines 2>/dev/null || echo 24)
        preview_width=\$((term_width / 3))
        preview_height=\$((term_height / 2))
        
        [[ \$preview_width -lt 40 ]] && preview_width=40
        [[ \$preview_height -lt 15 ]] && preview_height=15
        
        chafa --size="\${preview_width}x\${preview_height}" \
            --optimize=9 \
            --colors=full \
            --dither=bayer \
            --dither-intensity=0.5 \
            --color-space=rgb \
            --scale=max \
            "\$img_temp" 2>/dev/null
        echo ""
        rm -f "\$img_temp"
    fi
fi

# Check if we got valid response
if echo "\$response" | jq -e '.data.Media' > /dev/null 2>&1; then
    title=\$(echo "\$response" | jq -r '.data.Media.title.english // .data.Media.title.romaji // .data.Media.title.native')
    episodes=\$(echo "\$response" | jq -r '.data.Media.episodes // "?"')
    status=\$(echo "\$response" | jq -r '.data.Media.status // "Unknown"')
    score=\$(echo "\$response" | jq -r '.data.Media.averageScore // "N/A"')
    
    # User data
    user_progress=\$(echo "\$response" | jq -r '.data.MediaList.progress // "0"')
    user_status=\$(echo "\$response" | jq -r '.data.MediaList.status // ""')
    user_score=\$(echo "\$response" | jq -r '.data.MediaList.score // ""')
    
    # Format user status
    case "\$user_status" in
        "CURRENT") user_display="Currently Watching" ;;
        "PLANNING") user_display="Plan to Watch" ;;
        "COMPLETED") user_display="Completed" ;;
        "DROPPED") user_display="Dropped" ;;
        "PAUSED") user_display="On Hold" ;;
        "REPEATING") user_display="Rewatching" ;;
        *) user_display="Not in list" ;;
    esac
    
    # Calculate box width
    term_width=\$(tput cols 2>/dev/null || echo 80)
    box_width=\$((term_width - 10))
    [[ \$box_width -lt 60 ]] && box_width=60
    [[ \$box_width -gt 120 ]] && box_width=120
    hr=\$(printf '%*s' "\$box_width" | tr ' ' '─')
    
    echo "┌\${hr}┐"
    printf "│ %-*s \n" \$((box_width-2)) "\${title:0:\$((box_width-2))}"
    echo "├\${hr}┤"
    printf "│ Episodes: %-*s \n" \$((box_width-12)) "\$episodes"
    printf "│ Status: %-*s \n" \$((box_width-10)) "\$status"
    printf "│ Score: ⭐ %-*s \n" \$((box_width-10)) "\$score"
    
    # User progress section
    echo "├\${hr}┤"
    printf "│ \033[36mYour Library:\033[0m %-*s \n" \$((box_width-15)) ""
    printf "│ %-*s \n" \$((box_width-12)) "\$user_display"
    printf "│ Progress: %-*s \n" \$((box_width-12)) "\$user_progress / \$episodes"
    if [[ -n "\$user_score" && "\$user_score" != "0" && "\$user_score" != "null" ]]; then
        printf "│ Your Score: ⭐ %-*s \n" \$((box_width-12)) "\$user_score"
    fi
    echo "└\${hr}┘"
else
    error_msg=\$(echo "\$response" | jq -r '.errors[0].message // "Unknown error"')
    echo "Error: \$error_msg"
fi
EOF
    chmod +x "${script}"
}

# ==============================================
# LIBRARY ACTIONS
# ==============================================

# Update anime progress
update_anime_progress() {
    local anime_id="$1"
    local anime_name="$2"
    
    echo -e "\n${YELLOW}Current progress for ${anime_name}${NC}"
    
    # Get current progress
    local query='{"query":"query ($id: Int) { Media(id: $id) { episodes } }","variables":{"id":'"$anime_id"'}}'
    local response=$(curl -s -X POST "${ANILIST_API}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ANILIST_TOKEN}" \
        -d "${query}")
    
    local total_episodes=$(echo "${response}" | jq -r '.data.Media.episodes // "?"')
    
    echo -e "${GREEN}Total episodes: ${total_episodes}${NC}"
    echo -e "${GREEN}Enter new progress (number of episodes watched):${NC}"
    read -r new_progress
    
    if [[ "${new_progress}" =~ ^[0-9]+$ ]]; then
        local mutation='{"query":"mutation ($id: Int, $progress: Int) { SaveMediaListEntry(mediaId: $id, progress: $progress) { id progress } }","variables":{"id":'"$anime_id"',"progress":'"$new_progress"'}}'
        
        response=$(curl -s -X POST "${ANILIST_API}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${ANILIST_TOKEN}" \
            -d "${mutation}")
        
        if echo "${response}" | jq -e '.data.SaveMediaListEntry' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Progress updated to ${new_progress}${NC}"
            # Refresh library cache
            rm -f "${LIBRARY_CACHE}".*
        else
            echo -e "${RED}✗ Failed to update progress${NC}"
        fi
    fi
}

# Update anime score
update_anime_score() {
    local anime_id="$1"
    local anime_name="$2"
    
    echo -e "\n${YELLOW}Update score for ${anime_name}${NC}"
    echo -e "${GREEN}Enter score (0-100):${NC}"
    read -r new_score
    
    if [[ "${new_score}" =~ ^[0-9]+$ ]] && [[ "${new_score}" -ge 0 ]] && [[ "${new_score}" -le 100 ]]; then
        local mutation='{"query":"mutation ($id: Int, $score: Float) { SaveMediaListEntry(mediaId: $id, score: $score) { id score } }","variables":{"id":'"$anime_id"',"score":'"$new_score"'}}'
        
        local response=$(curl -s -X POST "${ANILIST_API}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${ANILIST_TOKEN}" \
            -d "${mutation}")
        
        if echo "${response}" | jq -e '.data.SaveMediaListEntry' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Score updated to ${new_score}${NC}"
            rm -f "${LIBRARY_CACHE}".*
        else
            echo -e "${RED}✗ Failed to update score${NC}"
        fi
    fi
}

# Update anime status
update_anime_status() {
    local anime_id="$1"
    local anime_name="$2"
    
    local status_options=(
        "CURRENT - Currently Watching"
        "PLANNING - Plan to Watch"
        "COMPLETED - Finished"
        "PAUSED - On Hold"
        "DROPPED - Dropped"
        "REPEATING - Rewatching"
    )
    
    local choice=$(printf '%s\n' "${status_options[@]}" | fzf --prompt="Select status: " --height=8 --border)
    local new_status=$(echo "${choice}" | cut -d' ' -f1)
    
    if [[ -n "${new_status}" ]]; then
        local mutation='{"query":"mutation ($id: Int, $status: MediaListStatus) { SaveMediaListEntry(mediaId: $id, status: $status) { id status } }","variables":{"id":'"$anime_id"',"status":"'"$new_status"'"}}'
        
        local response=$(curl -s -X POST "${ANILIST_API}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${ANILIST_TOKEN}" \
            -d "${mutation}")
        
        if echo "${response}" | jq -e '.data.SaveMediaListEntry' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Status updated to ${new_status}${NC}"
            rm -f "${LIBRARY_CACHE}".*
        else
            echo -e "${RED}✗ Failed to update status${NC}"
        fi
    fi
}

# Remove from library
remove_from_library() {
    local anime_id="$1"
    local anime_name="$2"
    
    echo -e "\n${YELLOW}Remove ${anime_name} from your list?${NC}"
    if fzf_confirm "Are you sure?"; then
        local query='{"query":"query ($id: Int) { MediaListEntry(mediaId: $id) { id } }","variables":{"id":'"$anime_id"'}}'
        local response=$(curl -s -X POST "${ANILIST_API}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${ANILIST_TOKEN}" \
            -d "${query}")
        
        local entry_id=$(echo "${response}" | jq -r '.data.MediaListEntry.id // ""')
        
        if [[ -n "${entry_id}" ]]; then
            local mutation='{"query":"mutation ($id: Int) { DeleteMediaListEntry(id: $id) { deleted } }","variables":{"id":'"$entry_id"'}}'
            
            response=$(curl -s -X POST "${ANILIST_API}" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${ANILIST_TOKEN}" \
                -d "${mutation}")
            
            if echo "${response}" | jq -e '.data.DeleteMediaListEntry.deleted' > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Removed from your list${NC}"
                rm -f "${LIBRARY_CACHE}".*
            else
                echo -e "${RED}✗ Failed to remove${NC}"
            fi
        fi
    fi
}

# ==============================================
# ADD TO LIBRARY
# ==============================================

# Add anime to library
add_to_library() {
    local anime_id="$1"
    local anime_name="$2"
    
    local status_options=(
        "CURRENT - Currently Watching"
        "PLANNING - Plan to Watch"
        "COMPLETED - Finished"
        "PAUSED - On Hold"
    )
    
    local choice=$(printf '%s\n' "${status_options[@]}" | fzf --prompt="Add as: " --height=6 --border)
    local status=$(echo "${choice}" | cut -d' ' -f1)
    
    if [[ -n "${status}" ]]; then
        local mutation='{"query":"mutation ($id: Int, $status: MediaListStatus) { SaveMediaListEntry(mediaId: $id, status: $status) { id status } }","variables":{"id":'"$anime_id"',"status":"'"$status"'"}}'
        
        local response=$(curl -s -X POST "${ANILIST_API}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${ANILIST_TOKEN}" \
            -d "${mutation}")
        
        if echo "${response}" | jq -e '.data.SaveMediaListEntry' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Added to your ${status} list${NC}"
            if [[ "${status}" = "CURRENT" ]]; then {
                update_anime_progress "${anime_id}" "${anime_name}"

            }
            fi
            rm -f "${LIBRARY_CACHE}".*
        else
            echo -e "${RED}✗ Failed to add to list${NC}"
        fi
    fi
}

# ==============================================
# MAIN MENU
# ==============================================

# Main AniList user menu
anilist_user_menu() {
    show_header
    
    # Check credentials first
    check_credentials || {
        echo -e "\n${YELLOW}Press Enter to continue${NC}"
        read -r
        show_main_menu
        return
    }
    
    while true; do
        
        local options=(
            "1. 👤 View Profile"
            "2. 📚 My Library"
            "3. 📊 Statistics"
            "4. 🚪 Logout"
            "5. 🔙 Back to Main Menu"
        )
        
        local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select option: " --height=10 --border)
        
        case "${choice}" in
            *"Profile"*|*"1."*) show_user_profile ;;
            *"Library"*|*"2."*) show_user_library ;;
            *"Statistics"*|*"3."*) show_user_statistics ;;
            *"Logout"*|*"4."*) logout_anilist ;;
            *) break ;;
        esac
        
        echo -e "\n${GREEN}Press Enter to continue${NC}"
        read -r
    done
    
    discover_anime
}

# Show user statistics
show_user_statistics() {
    check_credentials || return 1
    
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Anime Statistics${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    local query='{"query":"query { Viewer { statistics { anime { count episodesWatched minutesWatched meanScore standardDeviation scores { score count } formats { format count } statuses { status count } } } }"}'
    local response=$(curl -s -X POST "${ANILIST_API}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ANILIST_TOKEN}" \
        -d "${query}")
    
    if echo "${response}" | jq -e '.data.Viewer.statistics.anime' > /dev/null 2>&1; then
        local total=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.count')
        local episodes=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.episodesWatched')
        local minutes=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.minutesWatched')
        local mean=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.meanScore')
        local stddev=$(echo "${response}" | jq -r '.data.Viewer.statistics.anime.standardDeviation')
        
        local days=$((minutes / 1440))
        local hours=$(((minutes % 1440) / 60))
        
        echo -e "${GREEN}Total Anime:${NC} ${total}"
        echo -e "${GREEN}Episodes:${NC} ${episodes}"
        echo -e "${GREEN}Time Watched:${NC} ${days}d ${hours}h"
        echo -e "${GREEN}Mean Score:${NC} ⭐ ${mean}"
        echo -e "${GREEN}Std Deviation:${NC} ${stddev}"
        
        # Show score distribution
        echo -e "\n${YELLOW}Score Distribution:${NC}"
        echo "${response}" | jq -r '.data.Viewer.statistics.anime.scores[] | "  \(.score): \(.count)"' | sort -n
    else
        echo -e "${RED}Failed to fetch statistics${NC}"
    fi
}

# Sync library (force refresh)
sync_library() {
    echo -e "\n${YELLOW}Syncing library...${NC}"
    
    # Clear all caches
    rm -f "${LIBRARY_CACHE}".*
    
    # Force fetch fresh data
    if fetch_user_library "${ANILIST_USER_ID}" "ALL" true > /dev/null; then
        echo -e "${GREEN}✓ Library synced successfully${NC}"
    else
        echo -e "${RED}✗ Failed to sync library${NC}"
    fi
    
    echo -e "\n${GREEN}Press Enter to return to library menu${NC}"
    read -r
    
    # Return to library menu instead of going back to main menu
    show_user_library
}

# Logout
logout_anilist() {
    if fzf_confirm "Log out from AniList?"; then
        rm -f "${TOKEN_FILE}" "${USER_ID_FILE}"
        rm -f "${LIBRARY_CACHE}".*
        ANILIST_TOKEN=""
        ANILIST_USER_ID=""
        echo -e "${GREEN}✓ Logged out${NC}"
        sleep 1
    fi
}

# Initialize module
init_anilist_user