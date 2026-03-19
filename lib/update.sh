#!/usr/bin/env bash

# Update functions

# Check for updates for both ani-cli and wrapper
check_updates() {
    show_header
    
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Update Center${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    # Options for what to update
    local update_options=(
        "1. 🔄 Update ani-cli only"
        "2. 🔄 Update ani-cli-wrapper only"
        "3. 🔄 Update both"
        "4. 📊 Check versions only"
        "5. 🔙 Back to Main Menu"
    )
    
    local update_choice=$(printf '%s\n' "${update_options[@]}" | fzf --prompt="Select update option: " --height=12 --border --cycle)
    
    case "${update_choice}" in
        *"ani-cli only"*|*"1."*)
            update_ani_cli
            ;;
        *"wrapper only"*|*"2."*)
            update_ani_cli_wrapper
            ;;
        *"both"*|*"3."*)
            update_ani_cli
            update_ani_cli_wrapper
            ;;
        *"Check versions"*|*"4."*)
            check_versions
            ;;
        *)
            show_main_menu
            return
            ;;
    esac
    
    echo -e "\n${GREEN}Press Enter to continue${NC}"
    read -r
    show_main_menu
}

# Check versions of both ani-cli and wrapper
check_versions() {
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Version Information${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    # ani-cli version
    echo -e "${GREEN}ani-cli:${NC}"
    if command -V ani-cli &> /dev/null; then
        ani-cli -V 2>/dev/null || echo "  Version: Unknown"
        
        # Get install location
        local ani_path=$(which ani-cli)
        echo -e "  Location: ${ani_path}"
        
        # Check if update available
        local latest_ani=$(curl -s "https://api.github.com/repos/pystardust/ani-cli/releases/latest" 2>/dev/null | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
        if [[ -n "${latest_ani}" ]]; then
            echo -e "  Latest: ${latest_ani}"
        fi
    else
        echo -e "  ${RED}Not installed${NC}"
    fi
    
    echo ""
    
    # wrapper version
    echo -e "${GREEN}ani-cli-wrapper:${NC}"
    echo -e "  Version: ${CURRENT_VERSION}"
    echo -e "  Location: $(realpath "$0")"
    
    # Check wrapper latest
    local REPO_OWNER="scarletdragon9632"
    local REPO_NAME="ani-cli-wrapper"
    local latest_wrapper=$(curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" 2>/dev/null | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    if [[ -n "${latest_wrapper}" ]]; then
        echo -e "  Latest: ${latest_wrapper}"
    fi
    
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    
}

# Update ani-cli with confirmation
update_ani_cli() {
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}ani-cli Update${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    # Show current version
    echo -e "${GREEN}Current version:${NC}"
    ani-cli -V 2>/dev/null || echo "Unknown"
    
    # Check if update available (without actually updating)
    echo -e "\n${YELLOW}Checking for updates...${NC}"
    local check_output=$(ani-cli -U 2>&1)
    
    if echo "${check_output}" | grep -q "Script is up to date :)"; then
        echo -e "\n${GREEN}✓ ani-cli is already up to date!${NC}"
        sleep 2
        return
    elif echo "${check_output}" | grep -q "Updated"; then
        echo -e "\n${GREEN}✓ ani-cli has been updated!${NC}"
    else
        # Ask if user wants to update
        echo -e "\n${YELLOW}An update is available.${NC}"
        if fzf_confirm "Update now?"; then
            ani-cli -U
            echo -e "\n${GREEN}✓ Update complete!${NC}"
        else
            echo -e "\n${YELLOW}Update skipped${NC}"
        fi
    fi
    
    # Show final version
    echo -e "\n${GREEN}Current version:${NC}"
    ani-cli -V   2>/dev/null
    
    sleep 2
}

# Update ani-cli-wrapper
update_ani_cli_wrapper() {
    show_header
    
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Checking for Updates${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    # GitHub repository information
    local REPO_OWNER="scarletdragon9632"
    local REPO_NAME="ani-cli-wrapper"
    local CURRENT_VERSION=${CURRENT_VERSION}
    local SCRIPT_PATH="$(realpath "$0")"
    local SCRIPT_NAME="$(basename "$0")"
    
    echo -e "${GREEN}Current version: ${CURRENT_VERSION}${NC}"
    echo -e "${GREEN}Script location: ${SCRIPT_PATH}${NC}"
    
    # Check if running in debug mode (don't actually update)
    local DEBUG_MODE="${DEBUG:-false}"
    
    # Create temp directory for update
    local temp_dir=$(mktemp -d)
    cd "${temp_dir}" || return 1
    
    echo -e "\n${YELLOW}Fetching latest version from GitHub...${NC}"
    
    # Fetch latest release info from GitHub API
    local api_response=$(curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" 2>/dev/null)
    
    # Check if API request succeeded
    if [[ -z "${api_response}" ]] || echo "${api_response}" | grep -q "API rate limit exceeded"; then
        echo -e "${RED}Failed to check for updates. GitHub API rate limit may be exceeded.${NC}"
        echo -e "${YELLOW}Try again later or check manually at:${NC}"
        echo -e "https://github.com/${REPO_OWNER}/${REPO_NAME}/releases"
        sleep 3
        cd - > /dev/null
        rm -rf "${temp_dir}"
        show_main_menu
        return
    fi
    
    # Extract latest version
    local latest_version=$(echo "${api_response}" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    local download_url=$(echo "${api_response}" | grep -o '"browser_download_url": "[^"]*"' | cut -d'"' -f4)
    
    # If no release found, try to get from main branch
    if [[ -z "${latest_version}" ]]; then
        echo -e "${YELLOW}No release found, checking main branch...${NC}"
        latest_version=$(curl -s "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/version.txt" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        download_url="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/${SCRIPT_NAME}"
    fi
    
    # Compare versions
    if [[ "${latest_version}" != "${CURRENT_VERSION}" ]] && [[ "${latest_version}" != "unknown" ]]; then
        echo -e "\n${GREEN}New version available: ${latest_version}${NC}"
        echo -e "${YELLOW}Current version: ${CURRENT_VERSION}${NC}"
        
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Changelog:${NC}"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        
        # Fetch and display changelog
        local changelog=$(curl -s "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/CHANGELOG.md" 2>/dev/null | head -20)
        if [[ -n "${changelog}" ]]; then
            echo -e "${changelog}"
        else
            echo -e "No changelog available"
        fi
        
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        
        # Ask to update
        local update_options=(
            "✅ Update now (recommended)"
            "📝 View full changelog"
            "❌ Skip this version"
            "🔔 Remind me later"
        )
        
        local update_choice=$(printf '%s\n' "${update_options[@]}" | fzf --prompt="What would you like to do? " --height=10 --border)
        
        case "${update_choice}" in
            *"Update now"*)
                update_script "${download_url}" "${SCRIPT_PATH}" "${latest_version}"
                ;;
            *"View full changelog"*)
                curl -s "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/CHANGELOG.md" | less
                check_updates  # Recursive to show update prompt again
                ;;
            *"Skip"*)
                echo -e "${YELLOW}Version ${latest_version} skipped${NC}"
                # Save skipped version to config
                update_config "SKIPPED_VERSION" "${latest_version}"
                sleep 2
                ;;
            *"Remind"*)
                echo -e "${GREEN}Will remind you next time${NC}"
                sleep 2
                ;;
        esac
    elif [[ "${latest_version}" == "${CURRENT_VERSION}" ]]; then
        echo -e "\n${GREEN}✓ You're running the latest version (${CURRENT_VERSION})${NC}"
        
        # Offer to force reinstall
        if fzf_confirm "Reinstall current version?"; then
            update_script "${download_url}" "${SCRIPT_PATH}" "${CURRENT_VERSION}" "force"
        fi
    else
        echo -e "\n${YELLOW}Could not determine latest version.${NC}"
        echo -e "${GREEN}Current version: ${CURRENT_VERSION}${NC}"
        
        # Offer to check main branch
        if fzf_confirm "Check main branch for updates?"; then
            local main_version=$(curl -s "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/version.txt" 2>/dev/null)
            if [[ -n "${main_version}" ]]; then
                echo -e "${GREEN}Main branch version: ${main_version}${NC}"
                if [[ "${main_version}" != "${CURRENT_VERSION}" ]]; then
                    if fzf_confirm "Update to main branch version?"; then
                        update_script "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/${SCRIPT_NAME}" "${SCRIPT_PATH}" "${main_version}"
                    fi
                fi
            fi
        fi
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf "${temp_dir}"
    
    echo -e "\n${GREEN}Press Enter to continue${NC}"
    read -r
    show_main_menu
}

# Update the script
update_script() {
    local download_url="$1"
    local script_path="$2"
    local new_version="$3"
    local force="${4:-false}"
    
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Updating ani-cli-wrapper${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    # Create backup
    local backup_path="${script_path}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}Creating backup: ${backup_path}${NC}"
    cp "${script_path}" "${backup_path}"
    
    # Download new version
    echo -e "${YELLOW}Downloading new version...${NC}"
    local temp_script="${script_path}.new"
    
    if curl -s -L "${download_url}" -o "${temp_script}"; then
        # Verify download
        if [[ -s "${temp_script}" ]]; then
            # Check if it's a valid bash script
            if head -1 "${temp_script}" | grep -q "^#!/usr/bin/env bash\|^#!/bin/bash"; then
                # Make executable
                chmod +x "${temp_script}"
                
                # Show diff (optional)
                echo -e "\n${YELLOW}Changes in new version:${NC}"
                diff -u "${script_path}" "${temp_script}" | head -20 || true
                
                if [[ "${force}" == "force" ]] || fzf_confirm "Apply update and restart?"; then
                    # Replace current script
                    mv "${temp_script}" "${script_path}"
                    
                    # Update version in config
                    update_config "VERSION" "${new_version}"
                    
                    echo -e "\n${GREEN}✓ Update successful!${NC}"
                    echo -e "${YELLOW}Restarting with new version...${NC}"
                    sleep 2
                    
                    # Restart script
                    exec "${script_path}" "$@"
                else
                    echo -e "${YELLOW}Update cancelled${NC}"
                    rm -f "${temp_script}"
                fi
            else
                echo -e "${RED}Downloaded file is not a valid bash script${NC}"
                rm -f "${temp_script}"
            fi
        else
            echo -e "${RED}Downloaded file is empty${NC}"
            rm -f "${temp_script}"
        fi
    else
        echo -e "${RED}Failed to download update${NC}"
    fi
    
    echo -e "\n${YELLOW}Backup saved at: ${backup_path}${NC}"
    sleep 2
}