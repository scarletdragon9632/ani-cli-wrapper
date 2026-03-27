#!/usr/bin/env bash

# Settings menu functions

# Settings menu with fzf
show_settings_menu() {
    show_header
    
    while true; do
        local options=(
            "🎬 Quality (current: ${QUALITY})"
            "🎮 Player (current: ${PLAYER})"
            "🔤 Default Language (current: ${LANGUAGE})"
            "🔄 Auto Fallback to SUB when DUB is selected (current: ${AUTO_FALLBACK})"
            "📁 Download Directory (current: ${DOWNLOAD_DIR})"
            "📜 History File (current: ${HISTORY_FILE})"
            "⏭️  Skip Intro (current: ${SKIP_INTRO})"
            "🇺🇸  English Anime Title (current: ${ENGLISH_TITLE})"
            "🎨 Header Art (select ASCII art)"
            "🗑️  Clear Cache/History"
            "🔙 Back to Main Menu"
        )
        
        local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Settings: " --height=18 --border --cycle)
        
        case "${choice}" in
            *"Quality"*) change_quality ;;
            *"Player"*) change_player ;;
            *"Language"*) change_language ;;
            *"Auto Fallback to SUB when DUB is selected"*) toggle_setting "AUTO_FALLBACK" ;;
            *"Download Directory"*) change_download_dir ;;
            *"History File"*) change_history_file ;;
            *"Skip Intro"*) toggle_setting "SKIP_INTRO" ;;
            *"English Anime Title"*) toggle_setting "ENGLISH_TITLE" ;;
            *"Header Art"*) select_header_art ;;
            *"Clear Cache"*) clear_cache ;;
            *"Back"*) break ;;
        esac
    done
    
    show_main_menu
}

# Change quality setting
change_quality() {
    local options=("360p" "480p" "720p" "1080p" "best" "worst")
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select quality: " --height=10 --cycle)
    
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
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select player: " --height=5 --cycle)
    
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
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select default language: " --height=5 --cycle)
    
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

# Toggle boolean setting
toggle_setting() {
    local setting="$1"
    local current_value="${!setting}"
    
    local options=("✅ Enable" "❌ Disable")
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Toggle ${setting}: " --height=5 --border --cycle)
    
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

# Clear cache and history
clear_cache() {
    local options=(
        "Clear recent searches only"
        "Clear AniList cache only"
        "Clear watch history"
        "Clear everything"
        "Cancel"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="Clear options: " --height=12 --cycle)
    
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
    
    local color_choice=$(printf '%s\n' "${color_options[@]}" | fzf --prompt="Select color: " --height=10 --border --cycle)
    
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