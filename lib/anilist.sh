#!/usr/bin/env bash

# AniList API integration

# ==============================================
# IMAGE PREVIEW FUNCTIONS
# ==============================================

# Download thumbnails for search results
download_thumbnails() {
    local json_data="$1"
    local cache_dir="${CACHE_DIR}/anilist_thumbs"
    mkdir -p "$cache_dir"
    
    echo "${json_data}" | jq -r '.data.Page.media[]? | 
        "\(.coverImage.large // .coverImage.medium)␟\(.id)␟\(.title.english // .title.romaji // .title.native)"' 2>/dev/null | \
    while IFS='␟' read -r cover_url media_id title; do
        local thumb_file="${cache_dir}/${media_id}.jpg"
        if [[ ! -f "$thumb_file" ]]; then
            curl -s -L "$cover_url" -o "$thumb_file" 2>/dev/null &
        fi
    done
    wait
    echo "$cache_dir"
}

# Simple image preview with chafa
image_preview_fzf() {
    local cache_dir="$1"
    local search_term="$2"
    
    # Create a list with IDs and titles
    local items=""
    for img in "$cache_dir"/*.jpg; do
        [[ -f "$img" ]] || continue
        local id=$(basename "$img" .jpg)
        local title=$(jq -r --arg id "$id" '.data.Page.media[] | select(.id == ($id | tonumber)) | .title.english // .title.romaji // .title.native' "${ANILIST_CACHE}/search.json" 2>/dev/null)
        items+="${id}␟${title}"$'\n'
    done
    
    # Use fzf with chafa preview
    echo -n "$items" | fzf \
        --delimiter='␟' \
        --with-nth=2 \
        --prompt="Select anime: " \
        --height=60 \
        --cycle \
        --query="$search_term" \
        --preview="chafa --size=\${FZF_PREVIEW_COLUMNS}x\${FZF_PREVIEW_LINES} --format=symbols $cache_dir/{1}.jpg 2>/dev/null || echo 'No image available'" \
        --preview-window='right:60%' | cut -d'␟' -f1
}

# ==============================================
# SEARCH FUNCTIONALITY
# ==============================================

# Search anime on AniList
search_anilist() {
    local search_term="$1"
    local page="${2:-1}"
    local per_page="${3:-50}"
    
    if [[ -z "${search_term}" ]]; then
        echo -e "${RED}Search term cannot be empty${NC}" >&2
        return 1
    fi
    
    echo -e "\n${YELLOW}Searching AniList for: ${search_term}${NC}" >&2
    
    # Properly escape the search term for JSON
    local escaped_search=$(echo "${search_term}" | sed 's/"/\\"/g')
    
    # GraphQL query for search
    local query='{"query":"query ($search: String, $page: Int, $perPage: Int) { Page(page: $page, perPage: $perPage) { pageInfo { hasNextPage total } media(search: $search, type: ANIME, sort: SEARCH_MATCH) { id title { romaji english native } format episodes status averageScore genres coverImage { large } startDate { year } } } }","variables":{"search":"'"${escaped_search}"'","page":'"${page}"',"perPage":'"${per_page}"'}}'
    
    # Make the request with better error handling
    local response
    local http_code
    response=$(curl -s -w "%{http_code}" -X POST "https://graphql.anilist.co" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "${query}" 2>&1)
    
    # Extract HTTP code (last 3 characters)
    http_code="${response: -3}"
    response="${response%???}"
    
    # Check HTTP status
    if [[ "${http_code}" != "200" ]]; then
        echo -e "${RED}HTTP Error ${http_code} from AniList${NC}" >&2
        if [[ "${http_code}" == "429" ]]; then
            echo -e "${YELLOW}Rate limit exceeded. Please wait a moment and try again.${NC}" >&2
        fi
        return 1
    fi
    
    # Validate JSON
    if ! echo "${response}" | jq empty 2>/dev/null; then
        echo -e "${RED}Invalid JSON response from AniList${NC}" >&2
        return 1
    fi
    
    # Check for GraphQL errors
    if echo "${response}" | jq -e '.errors' > /dev/null 2>&1; then
        local error_msg=$(echo "${response}" | jq -r '.errors[0].message // "Unknown error"')
        echo -e "${RED}AniList API Error: ${error_msg}${NC}" >&2
        return 1
    fi
    
    # Check if we got results
    local total_results=$(echo "${response}" | jq '.data.Page.media | length' 2>/dev/null)
    
    if [[ -z "${total_results}" ]] || [[ "${total_results}" -eq 0 ]]; then
        echo -e "${YELLOW}No results found for '${search_term}'${NC}" >&2
        return 1
    fi
    
    echo -e "${GREEN}Found ${total_results} results${NC}" >&2
    echo "${response}"
    return 0
}

# ==============================================
# ADD TO LIBRARY FUNCTION
# ==============================================

# Add anime to library
add_to_library() {
    local anime_id="$1"
    local anime_name="$2"
    
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Add to Library: ${anime_name}${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    # Check if user is logged in
    if [[ -z "${ANILIST_TOKEN:-}" ]]; then
        echo -e "${YELLOW}You need to be logged in to AniList to add items.${NC}"
        if fzf_confirm "Log in to AniList now?"; then
            if [[ -f "${LIB_DIR}/anilist_user.sh" ]]; then
                source "${LIB_DIR}/anilist_user.sh"
                check_credentials
            else
                echo -e "${RED}AniList user module not found${NC}"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    local status_options=(
        "CURRENT - Currently Watching"
        "PLANNING - Plan to Watch"
        "COMPLETED - Finished"
        "PAUSED - On Hold"
    )
    
    local choice=$(printf '%s\n' "${status_options[@]}" | fzf --prompt="Add as: " --height=8 --border)
    
    if [[ -n "${choice}" ]]; then
        local status=$(echo "${choice}" | cut -d' ' -f1)
        local status_desc=$(echo "${choice}" | cut -d'-' -f2- | sed 's/^ //')
        
        echo -e "${YELLOW}Adding to ${status_desc} list...${NC}"
        
        local mutation='{"query":"mutation ($id: Int, $status: MediaListStatus) { SaveMediaListEntry(mediaId: $id, status: $status) { id status } }","variables":{"id":'"$anime_id"',"status":"'"$status"'"}}'
        
        local response=$(curl -s -X POST "https://graphql.anilist.co" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${ANILIST_TOKEN}" \
            -d "${mutation}")
        
        if echo "${response}" | jq -e '.data.SaveMediaListEntry' > /dev/null 2>&1; then
            local entry_status=$(echo "${response}" | jq -r '.data.SaveMediaListEntry.status')
            echo -e "${GREEN}✓ Added to your ${entry_status} list successfully!${NC}"
            rm -f "${LIBRARY_CACHE:-${CACHE_DIR}/library_cache}"* 2>/dev/null
        else
            echo -e "${RED}✗ Failed to add to list${NC}"
        fi
    fi
    
    sleep 1
}

# ==============================================
# FETCH FUNCTIONS
# ==============================================

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
  "query": "query { Page(page: 1, perPage: 50) { media(type: ANIME, sort: TRENDING_DESC) { id title { romaji english native } format episodes status description averageScore genres coverImage { large } trending popularity favourites nextAiringEpisode { airingAt timeUntilAiring episode } } } }"
}'
            ;;
        "popular")
            query='{
  "query": "query { Page(page: 1, perPage: 50) { media(type: ANIME, sort: POPULARITY_DESC) { id title { romaji english native } format episodes status description averageScore genres coverImage { large } } } }"
}'
            ;;
        "top_rated")
            query='{
  "query": "query { Page(page: 1, perPage: 50) { media(type: ANIME, sort: SCORE_DESC) { id title { romaji english native } format episodes status description averageScore genres coverImage { large } } } }"
}'
            ;;
        "seasonal")
            local year=$(date +%Y)
            local month=$(date +%m)
            local season=""
            
            if [[ $month -ge 3 && $month -le 5 ]]; then
                season="SPRING"
            elif [[ $month -ge 6 && $month -le 8 ]]; then
                season="SUMMER"
            elif [[ $month -ge 9 && $month -le 11 ]]; then
                season="FALL"
            else
                season="WINTER"
            fi
            
            query='{
  "query": "query { Page(page: 1, perPage: 50) { media(type: ANIME, season: '"$season"', seasonYear: '"$year"') { id title { romaji english native } format episodes status description averageScore genres coverImage { large } } } }"
}'
            ;;
        "upcoming")
            query='{
  "query": "query { Page(page: 1, perPage: 30) { media(type: ANIME, status: NOT_YET_RELEASED, sort: POPULARITY_DESC) { id title { romaji english native } format episodes status description averageScore genres coverImage { large } } } }"
}'
            ;;
        *)
            echo -e "${RED}Invalid query type: ${query_type}${NC}" >&2
            return 1
            ;;
    esac
    
    # Remove all newlines and extra spaces for the curl request
    local compact_query=$(echo "$query" | tr -d '\n' | sed 's/  */ /g')
    
    local response=$(curl -s -X POST "https://graphql.anilist.co" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$compact_query")
    
    # Check if response contains data
    if echo "$response" | jq -e '.data.Page.media' > /dev/null 2>&1; then
        echo "$response" > "${cache_file}"
        echo "$response"
    else
        echo -e "${RED}Failed to fetch ${query_type} anime${NC}" >&2
        return 1
    fi
}

# ==============================================
# ENHANCED PREVIEW SCRIPT
# ==============================================

# Create enhanced preview script
create_enhanced_preview_script() {
    local preview_script="${CACHE_DIR}/preview.sh"
    
    cat > "${preview_script}" << 'EOF'
#!/usr/bin/env bash
selected_line="$1"

# Function to format time until next episode
format_time_until() {
    local seconds="$1"
    if [[ -z "$seconds" || "$seconds" -le 0 ]]; then
        echo "Unknown"
        return
    fi
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    
    if [[ $days -gt 0 ]]; then
        echo "${days}d ${hours}h"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

# Function to format airing date
format_airing_date() {
    local timestamp="$1"
    if [[ -z "$timestamp" ]]; then
        echo "Unknown"
        return
    fi
    
    if date --version 2>/dev/null | grep -q GNU; then
        date -d "@${timestamp}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown"
    elif date -r "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null; then
        date -r "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null
    else
        echo "Unknown date"
    fi
}

# Extract ID from format
id=""
if [[ "$selected_line" =~ \[([0-9]+)\] ]]; then
    id="${BASH_REMATCH[1]}"
else
    id=$(echo "$selected_line" | grep -o '\[[0-9]*\]' | head -1 | tr -d '[]')
fi

if [[ -z "$id" ]]; then
    echo "┌────────────────────────────────────┐"
    echo "│ Select an anime to see details     │"
    echo "└────────────────────────────────────┘"
    exit 0
fi

# FIXED: Use the exact working query format
response=$(curl -s -X POST "https://graphql.anilist.co" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "{
        \"query\": \"query { Media(id: $id) { title { romaji english native } description episodes duration status season startDate { year } averageScore genres coverImage { extraLarge large medium } nextAiringEpisode { airingAt timeUntilAiring episode } } }\"
    }")

# Check if response contains data
if ! echo "$response" | jq -e '.data.Media' > /dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
    echo "Error fetching details: $error_msg"
    exit 1
fi

# Extract image URL and show it with chafa if available
image_url=$(echo "$response" | jq -r '.data.Media.coverImage.extraLarge // .data.Media.coverImage.large // .data.Media.coverImage.medium // ""')

if [[ -n "$image_url" ]] && command -v chafa &> /dev/null; then
    img_temp="/tmp/anime_preview_${id}.jpg"
    curl -s -L "$image_url" -o "$img_temp" 2>/dev/null
    
    if [[ -f "$img_temp" ]]; then
        term_width=$(tput cols 2>/dev/null || echo 80)
        term_height=$(tput lines 2>/dev/null || echo 24)
        preview_width=$((term_width / 3))
        preview_height=$((term_height / 2))
        
        [[ $preview_width -lt 40 ]] && preview_width=40
        [[ $preview_height -lt 15 ]] && preview_height=15
        
        chafa --size="${preview_width}x${preview_height}" \
            --optimize=9 \
            --colors=full \
            --dither=bayer \
            --dither-intensity=0.5 \
            --color-space=rgb \
            --scale=max \
            "$img_temp" 2>/dev/null
        echo ""
        rm -f "$img_temp"
    fi
fi

# Extract fields
title=$(echo "$response" | jq -r '.data.Media.title.english // .data.Media.title.romaji // .data.Media.title.native // "Unknown Title"')
episodes=$(echo "$response" | jq -r '.data.Media.episodes // "?"')
duration=$(echo "$response" | jq -r '.data.Media.duration // "?"')
status=$(echo "$response" | jq -r '.data.Media.status // "Unknown"')
season=$(echo "$response" | jq -r '.data.Media.season // "?"')
year=$(echo "$response" | jq -r '.data.Media.startDate.year // "?"')
score=$(echo "$response" | jq -r '.data.Media.averageScore // "N/A"')
genres=$(echo "$response" | jq -r '.data.Media.genres // [] | join(", ")')
next_episode=$(echo "$response" | jq -r '.data.Media.nextAiringEpisode.episode // ""')
next_time_until=$(echo "$response" | jq -r '.data.Media.nextAiringEpisode.timeUntilAiring // ""')
next_airing_at=$(echo "$response" | jq -r '.data.Media.nextAiringEpisode.airingAt // ""')

# Clean description
description=$(echo "$response" | jq -r '.data.Media.description // "No description available"' | 
    sed -E 's/<[^>]*>//g' |
    sed -E 's/&nbsp;/ /g' |
    sed -E 's/&[a-zA-Z]+;//g' |
    tr '\n' ' ' |
    sed -E 's/\s+/ /g' |
    sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

# Truncate description if too long
if [[ ${#description} -gt 300 ]]; then
    description="${description:0:300}..."
fi

# Calculate box width
term_width=$(tput cols 2>/dev/null || echo 80)
box_width=$((term_width - 10))
[[ $box_width -lt 60 ]] && box_width=60
[[ $box_width -gt 120 ]] && box_width=120

hr=$(printf '%*s' "$box_width" | tr ' ' '─')

echo "┌${hr}┐"
printf "│ %-*s \n" $((box_width-2)) "${title:0:$((box_width-2))}"
echo "├${hr}┤"
printf "│ Episodes: %-*s \n" $((box_width-12)) "$episodes"
printf "│ Duration: %-*s \n" $((box_width-12)) "${duration} min"
printf "│ Status: %-*s \n" $((box_width-10)) "$status"
printf "│ Season: %-*s \n" $((box_width-10)) "$season $year"
printf "│ Score: ⭐ %-*s \n" $((box_width-10)) "$score"
printf "│ Genres: %-*s \n" $((box_width-10)) "${genres:0:$((box_width-10))}"

if [[ -n "$next_episode" ]] && [[ "$status" == "RELEASING" ]]; then
    echo "├${hr}┤"
    printf "│ \033[32mNext Episode:\033[0m %-*s \n" $((box_width-15)) "Episode ${next_episode}"
    if [[ -n "$next_time_until" ]]; then
        time_formatted=$(format_time_until "$next_time_until")
        printf "│ \033[33mAiring in:\033[0m %-*s \n" $((box_width-13)) "${time_formatted}"
    fi
    if [[ -n "$next_airing_at" ]]; then
        airing_date=$(format_airing_date "$next_airing_at")
        printf "│ \033[36mAiring at:\033[0m %-*s \n" $((box_width-13)) "${airing_date}"
    fi
fi
echo "├${hr}┤"

echo "│ Description:"
echo "$description" | fold -w $((box_width-10)) -s | while IFS= read -r line; do
    printf "│ %-*s \n" $((box_width-2)) "$line"
done
echo "└${hr}┘"
EOF
    chmod +x "${preview_script}"
}

# ==============================================
# DISCOVER MENU
# ==============================================

# Discover anime menu
discover_anime() {
    show_header
    
    local options=(
        "🔍 Search AniList"
        "🔥 Trending Now"
        "⭐ Most Popular"
        "🏆 Top Rated"
        "🌸 Current Season"
        "🚀 Upcoming"
        "🔙 Back to Main Menu"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Discover: " --height=12 --border --cycle)
    
    set +e
    case "${choice}" in
        *"Search"*) interactive_anilist_search ;;
        *"Trending"*) show_anilist_results "trending" ;;
        *"Popular"*) show_anilist_results "popular" ;;
        *"Top Rated"*) show_anilist_results "top_rated" ;;
        *"Current Season"*) show_anilist_results "seasonal" ;;
        *"Upcoming"*) show_anilist_results "upcoming" ;;
        *) show_main_menu ;;
    esac
    set -e
    
    echo -e "\n${GREEN}Press Enter to continue${NC}"
    read -r
    discover_anime
}

# ==============================================
# INTERACTIVE SEARCH
# ==============================================

# Interactive search menu with image preview
interactive_anilist_search() {
    show_header
    
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}AniList Search${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    echo -e "${GREEN}Enter anime name to search:${NC}"
    echo -e "${YELLOW}Tip: Search is case-insensitive and matches English/Romaji titles${NC}"
    read -r search_term
    
    if [[ -z "${search_term}" ]]; then
        echo -e "${YELLOW}Search cancelled${NC}"
        sleep 1
        discover_anime
        return 0
    fi
    
    # Search first page
    local response=""
    local search_status=0
    
    set +e
    response=$(search_anilist "${search_term}" 1 50)
    search_status=$?
    set -e
    
    if [[ ${search_status} -ne 0 ]] || [[ -z "${response}" ]]; then
        echo -e "\n${YELLOW}No results found for '${search_term}'${NC}"
        echo -e "\n${GREEN}Press Enter to return to Discover menu${NC}"
        read -r
        discover_anime
        return 0
    fi
    
    # Save response
    echo "$response" > "${ANILIST_CACHE}/search.json"
    
    # Download thumbnails
    echo -e "${YELLOW}Loading thumbnails...${NC}"
    local thumb_cache=$(download_thumbnails "$response")
    
    # Create preview script
    create_enhanced_preview_script
    local preview_script="${CACHE_DIR}/preview.sh"
    
    # Parse results
    local anime_list=$(echo "${response}" | jq -r '.data.Page.media[]? | 
        "[\(.id)] " + 
        (.title.english // .title.romaji // .title.native) + 
        " | ⭐ " + (.averageScore // "N/A" | tostring) + 
        " | " + (.format // "TV") + 
        " | " + (.episodes // "?" | tostring) + " eps" + 
        " | " + (.startDate.year // "?" | tostring) +
        " | " + (.status // "Unknown")' 2>/dev/null)
    
    # Select anime
    local selected_id=$(echo "$anime_list" | fzf \
        --prompt="Select anime: " \
        --height=60 \
        --cycle \
        --preview="$preview_script {}" \
        --preview-window='right:60%' | grep -o "\[[0-9]*\]" | tr -d '[]')
    
    if [[ -n "$selected_id" ]]; then
        local anime_name=$(echo "$response" | jq -r --arg id "$selected_id" '.data.Page.media[] | select(.id == ($id | tonumber)) | .title.english // .title.romaji // .title.native')
        
        echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Selected: ${anime_name}${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        
        local action_options=(
            "▶️ Watch Now"
            "➕ Add to My List"
            "❌ Cancel"
        )
        
        local action=$(printf '%s\n' "${action_options[@]}" | fzf --prompt="Choose action: " --height=8 --border)
        
        case "${action}" in
            *"Watch"*)
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
            *"Add"*)
                add_to_library "$selected_id" "$anime_name"
                ;;
        esac
    fi
    
    rm -rf "$thumb_cache" 2>/dev/null
    echo -e "\n${GREEN}Press Enter to return to Discover menu${NC}"
    read -r
    discover_anime
}

# ==============================================
# DISPLAY RESULTS
# ==============================================

# Parse and display AniList results
show_anilist_results() {
    local query_type="$1"
    local json_data=$(fetch_anilist "${query_type}")
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}jq is required for AniList integration. Please install jq.${NC}"
        sleep 3
        return 1
    fi
    
    local anime_list=$(echo "${json_data}" | jq -r '.data.Page.media[] | 
        "[\(.id)] " + 
        (.title.english // .title.romaji // .title.native) + 
        " | ⭐ " + (.averageScore // "N/A" | tostring) + 
        " | " + (.format // "TV") + 
        " | " + (.episodes // "?" | tostring) + " eps" + 
        " | " + (.status // "Unknown") + 
        (.nextAiringEpisode | if . then " | Next: Ep " + (.episode | tostring) + " in " + ((.timeUntilAiring/ 3600) | floor | tostring) + "h" else "" end)' 2>/dev/null)
    
    if [[ -z "${anime_list}" ]]; then
        echo -e "${RED}No results found${NC}"
        return 1
    fi
    
    create_enhanced_preview_script
    local preview_script="${CACHE_DIR}/preview.sh"
    
    local selected=$(echo "${anime_list}" | fzf \
        --prompt="Select anime: " \
        --height=60 \
        --cycle \
        --preview="${preview_script} {}" \
        --preview-window='right:60%')
    
    if [[ -n "${selected}" ]]; then
        local anime_id=$(echo "${selected}" | grep -o "\[[0-9]*\]" | head -1 | tr -d '[]')
        local anime_name=$(echo "${selected}" | sed -E 's/^\[[0-9]+\] //;s/ \|.*//')
        
        echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Selected: ${anime_name}${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        
        local action_options=(
            "▶️ Watch Now"
            "➕ Add to My List"
            "❌ Cancel"
        )
        
        local action=$(printf '%s\n' "${action_options[@]}" | fzf --prompt="Choose action: " --height=8 --border)
        
        case "${action}" in
            *"Watch"*)
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
            *"Add"*)
                add_to_library "$anime_id" "$anime_name"
                ;;
        esac
    fi
}

# ==============================================
# SAFE RUN FUNCTION
# ==============================================

# Safe function to run commands that might fail
safe_run() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"
    
    set +e
    eval "$cmd"
    local exit_code=$?
    set -e
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${YELLOW}${error_msg} (continuing anyway)${NC}" >&2
        return $exit_code
    fi
    return 0
}