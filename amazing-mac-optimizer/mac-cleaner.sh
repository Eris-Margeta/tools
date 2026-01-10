#!/bin/bash

# A comprehensive script to clean, maintain, and configure macOS.
# Version 10.0 - The Master Control Edition. Fully compatible with default macOS Bash.

# --- Color Codes for Script Output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Global variable for tracking space saved ---
total_space_saved_kb=0

# --- Helper function to calculate directory size and add to total ---
add_directory_size_to_total() {
  local path="$1"
  if [ -d "$path" ]; then
    local size_kb
    size_kb=$(sudo du -sk "$path" | awk '{print $1}')
    if [[ "$size_kb" -gt 0 ]]; then
      total_space_saved_kb=$((total_space_saved_kb + size_kb))
    fi
  fi
}

# --- Core Cleaning Functions ---

clean_user_cache() {
  echo -e "${YELLOW}--- Cleaning User Cache ---${NC}"
  local cache_dir=~/Library/Caches
  add_directory_size_to_total "$cache_dir"
  if [ -d "$cache_dir" ]; then rm -rf "${cache_dir:?}"/* 2>/dev/null; fi
  echo -e "${GREEN}User Cache cleaned.${NC}"
}

clean_logs() {
  echo -e "${YELLOW}--- Cleaning Log Files ---${NC}"
  local user_log_dir=~/Library/Logs
  local system_log_dirs=(/Library/Logs /private/var/log)

  add_directory_size_to_total "$user_log_dir"
  if [ -d "$user_log_dir" ]; then
    rm -rf "${user_log_dir:?}"/*
    echo "User Logs cleaned."
  fi

  for dir in "${system_log_dirs[@]}"; do
    add_directory_size_to_total "$dir"
    if [ -d "$dir" ]; then
      sudo rm -rf "${dir:?}"/*
      echo "System Logs in ${dir} cleaned."
    fi
  done
  echo ""
}

clean_browser_caches() {
  echo -e "${YELLOW}--- Cleaning Browser Caches ---${NC}"
  local chrome_cache=~/Library/Caches/Google/Chrome
  local brave_cache=~/Library/Caches/BraveSoftware/Brave-Browser

  add_directory_size_to_total "$chrome_cache"
  if [ -d "$chrome_cache" ]; then
    rm -rf "${chrome_cache:?}"/*
    echo "Google Chrome cache cleaned."
  fi

  add_directory_size_to_total "$brave_cache"
  if [ -d "$brave_cache" ]; then
    rm -rf "${brave_cache:?}"/*
    echo "Brave Browser cache cleaned."
  fi
  echo -e "${GREEN}Browser caches cleaned.${NC}\n"
}

empty_trash() {
  echo -e "${YELLOW}--- Emptying Trash ---${NC}"
  local trash_dir=~/.Trash
  add_directory_size_to_total "$trash_dir"
  if [ -d "$trash_dir" ]; then rm -rf "${trash_dir:?}"/*; fi
  echo -e "${GREEN}Trash emptied.${NC}\n"
}

# --- Developer-focused Cleaning Functions ---

clean_dev_caches() {
  echo -e "${YELLOW}--- Cleaning Developer Caches ---${NC}"
  local logged_in_user=${SUDO_USER:-$(whoami)}
  local cache_names=("npm" "pnpm" "Yarn" "pip" "Poetry")
  local cache_paths=("~/.npm" "~/Library/pnpm/store" "~/Library/Caches/Yarn" "~/Library/Caches/pip" "~/Library/Caches/pypoetry")

  for ((i = 0; i < ${#cache_names[@]}; i++)); do
    local name="${cache_names[$i]}"
    local path_template="${cache_paths[$i]}"
    local expanded_path
    eval expanded_path="$path_template"
    add_directory_size_to_total "$expanded_path"
    if [ -d "$expanded_path" ]; then
      rm -rf "${expanded_path:?}"/*
      echo "${name} cache cleaned."
    fi
  done

  if command -v go &>/dev/null; then
    sudo -u "$logged_in_user" go clean -cache -modcache
    echo "Go caches cleaned."
  fi
  local cargo_registry=~/.cargo/registry
  if [ -d "$cargo_registry" ]; then
    add_directory_size_to_total "$cargo_registry"
    rm -rf "$cargo_registry/src" "$cargo_registry/index"
    echo "Cargo registry cache cleaned."
  fi
  echo -e "${GREEN}Developer cache cleanup complete.${NC}\n"
}

clean_xcode() {
  echo -e "${YELLOW}--- Cleaning Xcode Caches ---${NC}"
  local derived_data=~/Library/Developer/Xcode/DerivedData
  local archives=~/Library/Developer/ Xcode/Archives

  add_directory_size_to_total "$derived_data"
  if [ -d "$derived_data" ]; then
    rm -rf "${derived_data:?}"/*
    echo "Xcode Derived Data cleaned."
  fi

  add_directory_size_to_total "$archives"
  if [ -d "$archives" ]; then
    rm -rf "${archives:?}"/*
    echo "Xcode Archives cleaned."
  fi
  echo -e "${GREEN}Xcode caches cleaned.${NC}\n"
}

clean_docker() {
  echo -e "${YELLOW}--- Pruning Docker System ---${NC}"
  if ! command -v docker &>/dev/null; then
    echo "Docker not found. Skipping."
    return
  fi
  local logged_in_user=${SUDO_USER:-$(whoami)}
  echo "Running 'docker system prune -af'. This may take a while..."
  sudo -u "$logged_in_user" docker system prune -af
  echo -e "${GREEN}Docker system pruned.${NC}\n"
}

clean_homebrew() {
  echo -e "${YELLOW}--- Cleaning Homebrew Cache ---${NC}"
  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Skipping."
    return
  fi
  local logged_in_user=${SUDO_USER:-$(whoami)}
  echo "Running 'brew cleanup' as user '${logged_in_user}'..."
  sudo -u "$logged_in_user" brew cleanup
  echo -e "${GREEN}Homebrew cache cleaned.${NC}\n"
}

# --- System Configuration & Utility Functions ---

clean_macos_installers() {
  echo -e "${YELLOW}--- Searching for old macOS Installers ---${NC}"
  find /Applications -name "Install macOS*.app" -type d -maxdepth 1 | while read -r installer_path; do
    if [ -d "$installer_path" ]; then
      local installer_size
      installer_size=$(du -sh "$installer_path" | awk '{print $1}')
      echo "Found installer: $(basename "$installer_path") (Size: ${installer_size})"
      read -p "Do you want to delete this installer? (y/n): " delete_confirm
      if [[ "$delete_confirm" == "y" || "$delete_confirm" == "Y" ]]; then
        add_directory_size_to_total "$installer_path"
        sudo rm -rf "$installer_path"
        echo -e "${GREEN}Installer deleted.${NC}"
      fi
    fi
  done
  echo -e "${GREEN}Installer search complete.${NC}\n"
}

thin_universal_binaries() {
  echo -e "${YELLOW}--- Thinning Universal Binaries in /Applications ---${NC}"
  local ignore_list=("Safari" "Mail" "System Settings" "Numbers" "Pages" "Keynote")
  find /Applications -name "*.app" -maxdepth 2 | while read -r app_path; do
    app_name=$(basename "$app_path" .app)
    binary_path="${app_path}/Contents/MacOS/${app_name}"
    if [ -f "$binary_path" ] && [[ ! " ${ignore_list[@]} " =~ " ${app_name} " ]]; then
      archs=$(lipo -info "$binary_path" 2>/dev/null)
      if echo "$archs" | grep -q "arm64" && echo "$archs" | grep -q "x86_64"; then
        echo -e "Thinning universal binary: ${GREEN}${app_name}${NC}"
        if sudo lipo -thin arm64 "$binary_path" -output "${binary_path}_thin" && sudo mv "${binary_path}_thin" "$binary_path"; then
          echo " -> Done."
        else
          echo -e "${RED} -> Error thinning ${app_name}. Skipping.${NC}"
        fi
      fi
    fi
  done
  echo -e "${GREEN}Binary analysis complete.${NC}\n"
}

manage_snapshots() {
  echo -e "${YELLOW}--- Managing Time Machine Local Snapshots ---${NC}"
  local snapshot_list
  snapshot_list=$(tmutil listlocalsnapshots /)

  if [[ -z "$snapshot_list" ]]; then
    echo -e "${GREEN}No local snapshots found on the main drive.${NC}\n"
    return
  fi

  echo "Found the following local snapshots on your disk:"
  echo "$snapshot_list" | sed 's/^/  /'
  echo "These are automatically cleared by macOS when space is needed, but can be deleted now."

  read -p "Delete all of these local snapshots to reclaim space immediately? (y/n): " delete_confirm
  if [[ "$delete_confirm" == "y" || "$delete_confirm" == "Y" ]]; then
    echo "Deleting all local snapshots..."
    if sudo tmutil deletelocalsnapshots /; then
      echo -e "${GREEN}All local snapshots successfully deleted.${NC}"
    else
      echo -e "${RED}An error occurred while deleting snapshots.${NC}"
    fi
  fi
  echo ""
}

manage_spotlight() {
  echo -e "${YELLOW}--- Managing Spotlight Indexing ---${NC}"
  read -p "Do you want to completely DISABLE Spotlight and ERASE its index? (y/n): " disable_confirm
  if [[ "$disable_confirm" == "y" || "$disable_confirm" == "Y" ]]; then
    echo "Disabling Spotlight indexing for all volumes..."
    sudo mdutil -a -i off
    echo "Erasing the Spotlight index (this may take a moment)..."
    sudo mdutil -E /
    echo "Placing '.metadata_never_index' flags to prevent future indexing..."
    touch ~/.metadata_never_index
    sudo touch /Applications/.metadata_never_index
    touch ~/Documents/.metadata_never_index
    echo -e "${GREEN}Spotlight has been disabled and its index erased.${NC}"
  else
    echo "Skipping Spotlight management."
  fi
  echo ""
}

# --- Final display function ---
display_total_saved() {
  if [[ "$total_space_saved_kb" -gt 0 ]]; then
    local total_saved_mb=$((total_space_saved_kb / 1024))
    if [[ "$total_saved_mb" -gt 1024 ]]; then
      local total_saved_gb
      total_saved_gb=$(echo "scale=2; $total_space_saved_kb / 1024 / 1024" | bc)
      echo -e "${GREEN}🎉 Total space reclaimed (excluding Docker/Homebrew): approximately ${total_saved_gb} GB!${NC}"
    else
      echo -e "${GREEN}🎉 Total space reclaimed (excluding Docker/Homebrew): approximately ${total_saved_mb} MB!${NC}"
    fi
  fi
}

# --- Main orchestrator function ---
main() {
  echo -e "${GREEN}--- macOS Cleaner v10.0 (Master Control Edition) ---${NC}"

  echo -e "\n--- General System Cleanup ---"
  read -p "1. Clean caches (User, System, Browsers) and Logs? (y/n): " clean_general_caches
  read -p "2. Empty the Trash? (y/n): " empty_trash_confirm
  read -p "3. Search for and delete old macOS installers? (y/n): " clean_installers_confirm

  echo -e "\n--- Developer & Power User Tools ---"
  read -p "4. Clean developer caches (npm, pip, Xcode, etc.)? (y/n): " clean_dev_confirm
  read -p "5. Clean Homebrew cache? (y/n): " clean_homebrew_confirm
  read -p "6. Prune Docker system? (y/n): " clean_docker_confirm
  read -p "7. Thin universal application binaries? (y/n): " thin_binaries_confirm

  echo -e "\n--- System Configuration (Advanced) ---"
  read -p "8. Manage/Delete Time Machine local snapshots? (y/n): " manage_snapshots_confirm
  read -p "9. Disable and erase Spotlight Index? (y/n): " manage_spotlight_confirm

  # Prime sudo upfront for a smoother experience
  echo -e "\nSome operations require administrator privileges."
  sudo -v

  echo -e "\n${YELLOW}--- Starting Operations ---${NC}"

  # Execute based on user choices
  if [[ "$clean_general_caches" == "y" ]]; then
    clean_user_cache
    clean_logs
    clean_browser_caches
  fi
  if [[ "$empty_trash_confirm" == "y" ]]; then empty_trash; fi
  if [[ "$clean_installers_confirm" == "y" ]]; then clean_macos_installers; fi
  if [[ "$clean_dev_confirm" == "y" ]]; then
    clean_dev_caches
    clean_xcode
  fi
  if [[ "$clean_homebrew_confirm" == "y" ]]; then clean_homebrew; fi
  if [[ "$clean_docker_confirm" == "y" ]]; then clean_docker; fi
  if [[ "$thin_binaries_confirm" == "y" ]]; then thin_universal_binaries; fi
  if [[ "$manage_snapshots_confirm" == "y" ]]; then manage_snapshots; fi
  if [[ "$manage_spotlight_confirm" == "y" ]]; then manage_spotlight; fi

  # --- Grand Finale ---
  display_total_saved

  echo -e "${GREEN}--- All selected tasks are finished! ---${NC}"
}

# --- Run the main function ---
main
