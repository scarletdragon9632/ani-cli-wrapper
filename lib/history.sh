#!/usr/bin/env bash

# History management functions

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
                    total_ep="${BASH_REMATCH[3]}"
                    echo "Anime Details"           
                    echo ""
                    echo "Title: $title"
                    echo "Episode(s) Watched: $ep"
                else
                    echo "Select an option or search for anime"
                fi
            ' \
            --bind 'ctrl-s:change-prompt(Search> )' \
            --bind 'ctrl-c:cancel')
    
    # Handle selection
    if [[ -n "${selected}" ]]; then
        case "${selected}" in
           
                
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
                    local anime_title=$(echo "${BASH_REMATCH[2]}" | sed -E 's/\s*\([0-9]+\s*episodes\)\s*$//')
                    
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
                            [[ "${ENGLISH_TITLE}" == true ]] && cmd+=" --en"
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
                                [[ "${ENGLISH_TITLE}" == true ]] && cmd+=" --en"
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
                            [[ "${ENGLISH_TITLE}" == true ]] && cmd+=" --en"
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