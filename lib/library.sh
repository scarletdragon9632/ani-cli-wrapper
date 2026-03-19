#!/usr/bin/env bash

# Library/watchlist functions

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
                    local lang_choice=$(printf '%s\n' "${lang_options[@]}" | fzf --prompt="Language: " --height=5 --cycle)
                    
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