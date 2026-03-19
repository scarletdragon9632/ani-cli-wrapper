#!/usr/bin/env bash

# Download functions

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

quick_download() {
    ani-cli -d "$1"
    exit 0
}