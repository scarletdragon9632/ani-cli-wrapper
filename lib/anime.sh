#!/usr/bin/env bash

# Anime search and playback functions

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
        echo -e "${YELLOW}Example: Use just 'Hell Paradise' search or use Romaji Title 'Jigokuraku' (Recommended) instead of \"Hell's Paradise\"${NC}"
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
        echo -e "  • ${WHITE}Hell's Paradise${NC} → ${GREEN}Hell Paradise${NC} or ${GREEN}Jigokuraku${NC}"
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
        [[ "${ENGLISH_TITLE}" == true ]] && cmd+=" --en" 
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
                [[ "${ENGLISH_TITLE}" == true ]] && cmd+=" --en"
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
        [[ "${ENGLISH_TITLE}" == true ]] && cmd+=" --en"
        cmd+=" ${search_term}"
        
        echo -e "\n${GREEN}Launching:${NC} ${cmd}"
        eval "${cmd}"
    fi
}

# Quick search from command line
quick_search() {
    execute_with_fallback "$1" "${LANGUAGE}" "${QUALITY}" "${PLAYER}" "${SKIP_INTRO}"
    exit 0
}