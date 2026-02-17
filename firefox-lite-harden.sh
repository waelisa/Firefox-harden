#!/bin/bash

#############################################################################################################################
# The MIT License (MIT)
# Wael Isa
# Build Date: 02/18/2026
# Version: 1.0.0
# https://github.com/waelisa/firefox-lite-harden
#############################################################################################################################
# Firefox Lite Privacy Hardening Script
# Balances privacy with usability (banking sites, Firefox homepage work)
# Features:
#   ✓ Banking-friendly configuration (cookies preserved, resistFingerprinting OFF)
#   ✓ Firefox homepage remains functional
#   ✓ Video calls supported (WebRTC enabled)
#   ✓ Multi-platform support (Native, Flatpak, Snap)
#   ✓ Automatic profile detection
#   ✓ Safe backup creation before modifications
#   ✓ New profile creation option
#   ✓ Firefox process check to prevent conflicts
#   ✓ Clean exit handling
#############################################################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Firefox is running
check_firefox_running() {
    if pgrep -x "firefox" > /dev/null || pgrep -x "firefox-bin" > /dev/null; then
        print_error "Firefox is currently running. Please close it before applying hardening."
        print_info "Running Firefox can overwrite changes when it closes."
        echo -n "Force continue anyway? (y/n): "
        read -r force_continue
        if [[ ! "$force_continue" =~ ^[Yy]$ ]]; then
            exit 1
        fi
        print_warning "Continuing with Firefox running - changes may not persist!"
    else
        print_success "Firefox is not running - good!"
    fi
}

# Function to check if Firefox is installed
check_firefox() {
    if ! command -v firefox &> /dev/null; then
        print_error "Firefox is not installed. Please install Firefox first."
        exit 1
    fi
    print_success "Firefox found: $(firefox --version)"
}

# Function to find Firefox profile directory
find_firefox_profile() {
    local profile_found=false
    local profile_dirs=(
        "$HOME/.mozilla/firefox/*.default*"
        "$HOME/.mozilla/firefox/*.default-release*"
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox/*.default*"  # Flatpak
        "$HOME/snap/firefox/common/.mozilla/firefox/*.default*"  # Snap
        "$HOME/.mozilla/firefox/*.privacy-lite"  # Custom profile
    )

    for pattern in "${profile_dirs[@]}"; do
        for dir in $pattern; do
            if [ -d "$dir" ] && [ -f "$dir/prefs.js" ]; then
                FIREFOX_PROFILE="$dir"
                profile_found=true
                print_success "Found Firefox profile: $FIREFOX_PROFILE"
                break 2
            fi
        done
    done

    if [ "$profile_found" = false ]; then
        print_error "Could not find Firefox profile directory."
        print_info "Please start Firefox at least once to create a profile."
        exit 1
    fi
}

# Function to backup existing configuration
backup_config() {
    local backup_dir="$HOME/firefox-lite-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    if [ -f "$FIREFOX_PROFILE/prefs.js" ]; then
        cp "$FIREFOX_PROFILE/prefs.js" "$backup_dir/"
        print_success "Backed up prefs.js to $backup_dir/"
    fi

    if [ -f "$FIREFOX_PROFILE/user.js" ]; then
        cp "$FIREFOX_PROFILE/user.js" "$backup_dir/"
        print_success "Backed up user.js to $backup_dir/"
    fi

    # Set secure permissions on backup
    chmod 640 "$backup_dir"/* 2>/dev/null || true

    print_info "Backup location: $backup_dir"
}

# Function to set preference in user.js
set_pref() {
    local pref_name="$1"
    local pref_value="$2"
    local pref_type="$3"
    local user_js="$FIREFOX_PROFILE/user.js"

    # Format the preference line based on type
    case "$pref_type" in
        "string")
            pref_line="user_pref(\"$pref_name\", \"$pref_value\");"
            ;;
        "bool")
            pref_line="user_pref(\"$pref_name\", $pref_value);"
            ;;
        "int")
            pref_line="user_pref(\"$pref_name\", $pref_value);"
            ;;
        *)
            pref_line="user_pref(\"$pref_name\", $pref_value);"
            ;;
    esac

    # Check if preference already exists in user.js
    if grep -q "^user_pref(\"$pref_name\"" "$user_js" 2>/dev/null; then
        # Replace existing line
        sed -i "s|^user_pref(\"$pref_name\".*|$pref_line|" "$user_js"
    else
        # Append new line
        echo "$pref_line" >> "$user_js"
    fi

    print_info "Set: $pref_name = $pref_value"
}

# Function to create/initialize user.js
init_user_js() {
    local user_js="$FIREFOX_PROFILE/user.js"

    # Create header with timestamp and author info
    cat > "$user_js" << EOF
// Firefox Lite Privacy Hardening Script
// Author: Wael Isa
// GitHub: https://github.com/waelisa/firefox-lite-harden
// Applied on: $(date)
// This is a BALANCED approach - keeps banking sites working and Firefox homepage functional
// Version: 1.0.0

EOF

    print_success "Initialized user.js"
}

# Lite hardening function (balanced approach)
apply_lite_hardening() {
    local user_js="$FIREFOX_PROFILE/user.js"

    print_info "Starting Firefox LITE privacy hardening (banking-friendly)..."

    # Create or append to user.js
    if [ ! -f "$user_js" ]; then
        init_user_js
    else
        print_warning "user.js already exists. New settings will be appended."
        echo -e "\n\n// Additional lite settings added on: $(date)" >> "$user_js"
    fi

    # === PRIVACY & TRACKING - MODERATE ===
    print_info "Applying balanced privacy and tracking settings..."
    set_pref "privacy.trackingprotection.enabled" "true" "bool"  # Basic tracking protection
    set_pref "privacy.trackingprotection.socialtracking.enabled" "true" "bool"
    set_pref "privacy.trackingprotection.fingerprinting.enabled" "false" "bool"  # OFF to prevent breakage
    set_pref "privacy.trackingprotection.cryptomining.enabled" "true" "bool"
    set_pref "privacy.donottrackheader.enabled" "true" "bool"  # Send DNT signal

    # === COOKIES - BANKING FRIENDLY ===
    print_info "Applying cookie settings (banking-friendly)..."
    set_pref "network.cookie.lifetimePolicy" "0" "int"  # 0 = Accept cookies normally (banking sites need this)
    set_pref "privacy.clearOnShutdown.cookies" "false" "bool"  # Keep cookies (essential for banking)
    set_pref "privacy.clearOnShutdown.cache" "true" "bool"  # Clear cache on shutdown
    set_pref "privacy.clearOnShutdown.history" "true" "bool"  # Clear history on shutdown
    set_pref "privacy.clearOnShutdown.formdata" "true" "bool"  # Clear form data
    set_pref "privacy.sanitize.sanitizeOnShutdown" "true" "bool"  # Sanitize on shutdown

    # === ADDRESS BAR - MODERATE ===
    print_info "Applying address bar settings..."
    set_pref "browser.urlbar.suggest.history" "false" "bool"  # Don't suggest history
    set_pref "browser.urlbar.suggest.bookmark" "true" "bool"  # Keep bookmarks suggestions (useful)
    set_pref "browser.urlbar.suggest.topsites" "false" "bool"  # No topsites
    set_pref "browser.search.suggest.enabled" "false" "bool"  # Disable search suggestions

    # === SECURITY - KEEP ESSENTIALS ===
    print_info "Applying essential security settings..."
    set_pref "browser.safebrowsing.malware.enabled" "true" "bool"  # Keep malware protection
    set_pref "browser.safebrowsing.phishing.enabled" "true" "bool"  # Keep phishing protection
    set_pref "browser.safebrowsing.downloads.enabled" "true" "bool"  # Keep download scanning

    # === HTTPS - FLEXIBLE ===
    print_info "Applying HTTPS settings..."
    set_pref "dom.security.https_only_mode" "false" "bool"  # OFF - some banking sites use mixed content
    set_pref "dom.security.https_only_mode_pbm" "true" "bool"  # ON only in private mode

    # === PASSWORDS - KEEP OPTIONAL ===
    print_info "Applying password settings..."
    set_pref "signon.rememberSignons" "false" "bool"  # Don't save passwords (use password manager instead)
    set_pref "signon.autofillForms" "false" "bool"  # Don't autofill
    set_pref "browser.formfill.enable" "false" "bool"  # Don't save form history

    # === HOME PAGE & NEW TAB - KEEP FIREFOX DEFAULT ===
    print_info "Keeping Firefox homepage functional..."
    set_pref "browser.newtabpage.enabled" "true" "bool"  # Keep default new tab
    set_pref "browser.newtabpage.activity-stream.feeds.snippets" "true" "bool"  # Keep snippets (helpful)
    set_pref "browser.newtabpage.activity-stream.showSponsored" "false" "bool"  # Just disable sponsored

    # === UI CLEANUP - REMOVE INTRUSIVE ELEMENTS ===
    print_info "Removing intrusive UI elements..."
    set_pref "browser.tabs.firefox-view" "false" "bool"  # Disable Firefox View button
    set_pref "browser.shopping.experience2023.enabled" "false" "bool"  # Disable shopping sidebar

    # === TELEMETRY - DISABLE (NO IMPACT ON BANKING) ===
    print_info "Disabling telemetry (safe to disable)..."
    set_pref "datareporting.healthreport.uploadEnabled" "false" "bool"
    set_pref "datareporting.policy.dataSubmissionEnabled" "false" "bool"
    set_pref "toolkit.telemetry.enabled" "false" "bool"
    set_pref "toolkit.telemetry.unified" "false" "bool"

    # === WEBRTC - KEEP ENABLED ===
    print_info "Keeping WebRTC enabled (needed for video calls)..."
    set_pref "media.peerconnection.enabled" "true" "bool"  # Keep ON for video calls/banking support

    # === GEOLOCATION - PROMPT (BALANCED) ===
    print_info "Applying geolocation settings..."
    set_pref "geo.enabled" "true" "bool"  # Keep enabled but will prompt
    set_pref "geo.provider.network.url" "https://location.services.mozilla.com/v1" "string"  # Default

    # === DISABLE NON-ESSENTIAL SERVICES ===
    print_info "Disabling non-essential services..."
    set_pref "extensions.pocket.enabled" "false" "bool"  # Disable Pocket
    set_pref "browser.topsites.contile.enabled" "false" "bool"  # Disable sponsored tiles

    # === NETWORK - MODERATE ===
    print_info "Applying moderate network settings..."
    set_pref "network.prefetch-next" "false" "bool"  # Disable prefetching
    set_pref "network.dns.disablePrefetch" "true" "bool"  # Disable DNS prefetching
    set_pref "network.predictor.enabled" "false" "bool"  # Disable network prediction

    # === DO NOT ENABLE RESIST FINGERPRINTING ===
    # privacy.resistFingerprinting = false (default) - this breaks many banking sites
    print_info "✓ resistFingerprinting is OFF (banking sites need this)"

    # Set secure permissions on user.js
    chmod 640 "$user_js"

    print_success "Lite privacy hardening complete! Banking sites should work normally."
}

# Function to display notes about banking sites
show_banking_notes() {
    echo -e "\n${GREEN}=== Banking & Usability Notes ===${NC}"
    echo -e "${BLUE}Your Firefox is now configured with:${NC}"
    echo -e "  ✓ ${GREEN}Banking sites should work normally${NC} (cookies kept, resistFingerprinting OFF)"
    echo -e "  ✓ ${GREEN}Firefox homepage stays functional${NC} (snippets, new tab page)"
    echo -e "  ✓ ${GREEN}Video calls work${NC} (WebRTC enabled)"
    echo -e "  ✓ ${GREEN}Location services work${NC} (but will prompt)"
    echo -e "  ✓ ${GREEN}HTTPS is flexible${NC} (not forced, so banking sites with mixed content work)"
    echo -e ""
    echo -e "${YELLOW}Privacy improvements:${NC}"
    echo -e "  ✓ Tracking protection enabled"
    echo -e "  ✓ History cleared on shutdown"
    echo -e "  ✓ Telemetry disabled"
    echo -e "  ✓ Search suggestions disabled"
    echo -e "  ✓ Sponsored content disabled"
    echo -e "  ✓ Prefetching disabled"
    echo -e "  ✓ Firefox View button disabled"
    echo -e "  ✓ Shopping sidebar disabled"
    echo -e ""
    echo -e "${BLUE}What's NOT changed (for compatibility):${NC}"
    echo -e "  • Cookies are kept (banking sessions persist)"
    echo -e "  • resistFingerprinting is OFF"
    echo -e "  • HTTPS-only mode is OFF (only in private mode)"
    echo -e "  • WebRTC is ON"
    echo -e "  • Geolocation is ON (but prompts)"
}

# Function to display recommended add-ons (optional)
show_optional_addons() {
    echo -e "\n${GREEN}=== Optional Privacy Add-ons (Banking-Safe) ===${NC}"
    echo -e "${YELLOW}These add-ons add privacy WITHOUT breaking banking sites:${NC}"
    echo -e "  ${BLUE}1. uBlock Origin${NC} - https://addons.mozilla.org/firefox/addon/ublock-origin/"
    echo -e "     (Use in medium mode - blocks ads without breaking sites)"
    echo -e ""
    echo -e "  ${BLUE}2. Firefox Multi-Account Containers${NC} - https://addons.mozilla.org/firefox/addon/multi-account-containers/"
    echo -e "     (Isolate banking from other browsing - highly recommended)"
    echo -e ""
    echo -e "  ${BLUE}3. ClearURLs${NC} - https://addons.mozilla.org/firefox/addon/clearurls/"
    echo -e "     (Removes tracking from URLs, safe for banking)"
}

# Function to create a launcher script
create_launcher() {
    local launcher_dir="$HOME/.local/bin"
    mkdir -p "$launcher_dir"

    cat > "$launcher_dir/firefox-lite" << EOF
#!/bin/bash
# Firefox Lite Privacy Profile Launcher
# Created by Wael Isa's hardening script
firefox -P privacy-lite "\$@"
EOF

    chmod +x "$launcher_dir/firefox-lite"

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo -e "\n${YELLOW}Add this to your ~/.bashrc or ~/.zshrc:${NC}"
        echo 'export PATH="$HOME/.local/bin:$PATH"'
    fi

    print_success "Created launcher: $launcher_dir/firefox-lite"
}

# Main execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Firefox LITE Privacy Hardening   ${NC}"
    echo -e "${GREEN}   (Banking-Friendly Edition)       ${NC}"
    echo -e "${GREEN}   Author: Wael Isa                 ${NC}"
    echo -e "${GREEN}   Version: 1.0.0                   ${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Check if Firefox is installed
    check_firefox

    # Check if Firefox is running
    check_firefox_running

    # Ask about new profile
    echo -e "\n${YELLOW}Create a new profile for these settings?${NC}"
    echo "This keeps your current Firefox separate (recommended)"
    echo -n "Create new profile? (y/n): "
    read -r create_profile

    if [[ "$create_profile" =~ ^[Yy]$ ]]; then
        print_info "Creating new Firefox profile..."
        firefox -CreateProfile "privacy-lite"
        print_success "New profile 'privacy-lite' created."

        # Find the new profile directory
        sleep 2  # Give Firefox time to create the profile
        find_firefox_profile

        print_info "Launch with: ${GREEN}firefox -P privacy-lite${NC}"

        # Create convenient launcher
        create_launcher
    else
        # Find existing Firefox profile
        find_firefox_profile

        # Backup existing config
        print_info "Creating backup..."
        backup_config
    fi

    # Apply lite hardening
    apply_lite_hardening

    # Show banking notes
    show_banking_notes

    # Show optional add-ons
    show_optional_addons

    echo -e "\n${GREEN}=== Script Complete ===${NC}"
    print_success "Firefox is now configured with balanced privacy settings!"
    print_info "Please restart Firefox to apply all changes."

    if [[ "$create_profile" =~ ^[Yy]$ ]]; then
        print_info "Start your new profile with: ${GREEN}firefox -P privacy-lite${NC}"
        print_info "Or use the launcher: ${GREEN}firefox-lite${NC}"
    fi
}

# Run the main function
main
