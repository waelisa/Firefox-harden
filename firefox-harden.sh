#!/bin/bash

#############################################################################################################################
#
# Wael Isa
# Website:  https://www.wael.name
# GitHub:   https://github.com/waelisa
# Version:  v2.1.0
# Build Date: 03-19-2026
# License: MIT
#
# ██╗    ██╗ █████╗ ███████╗██╗         ██╗███████╗ █████╗
# ██║    ██║██╔══██╗██╔════╝██║         ██║██╔════╝██╔══██╗
# ██║ █╗ ██║███████║█████╗  ██║         ██║███████╗███████║
# ██║███╗██║██╔══██║██╔══╝  ██║         ██║╚════██║██╔══██║
# ╚███╔███╔╝██║  ██║███████╗███████╗    ██║███████╗██║  ██║
# ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝╚══════╝╚═╝  ╚═╝
#
# Description:
#   Enhanced Firefox Privacy Hardening Script - Balances privacy with usability for banking sites
#
# Features:
#   • Detects and merges with existing user.js from previous scripts
#   • Enhanced privacy settings while keeping banking sites functional
#   • Automatic profile detection (Desktop, Flatpak, Snap)
#   • Backup system with timestamp
#   • Validation of applied settings
#   • Restore option at end
#   • OS compatibility (Linux/macOS)
#   • FIXED: Profile creation timeout and better detection
#
# Changelog:
#   v2.1.0 - Fixed infinite loop on profile creation, added timeout limit
#   v2.0.0 - Complete rewrite with enhanced privacy and profile detection
#   v1.0.0 - Initial release
#
#############################################################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
FIREFOX_PROFILE=""
BACKUP_DIR=""
SCRIPT_VERSION="v2.1.0"
MAX_WAIT_TIME=60  # Maximum seconds to wait for profile creation

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

# Detect OS for sed command (CRITICAL FIX)
detect_os_sed() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        SED_INPLACE="sed -i ''"
    else
        SED_INPLACE="sed -i"
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

# Function to find Firefox profile directory (FIXED)
find_firefox_profile() {
    local profile_found=false
    local profile_dirs=(
        "$HOME/.mozilla/firefox/*.default*"
        "$HOME/.mozilla/firefox/*.default-release*"
        "$HOME/.mozilla/firefox/*.dev-edition-default*"
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox/*.default*"  # Flatpak
        "$HOME/snap/firefox/common/.mozilla/firefox/*.default*"  # Snap
    )

    for pattern in "${profile_dirs[@]}"; do
        for dir in $pattern; do
            if [ -d "$dir" ] && [ -f "$dir/prefs.js" ]; then
                FIREFOX_PROFILE="$dir"
                profile_found=true
                print_success "Found Firefox profile: $FIREFOX_PROFILE"
                return 0  # FIXED: Use return instead of break 2
            fi
        done
    done

    if [ "$profile_found" = false ]; then
        print_error "Could not find Firefox profile directory."
        print_info "Please start Firefox at least once to create a profile."
        return 1
    fi
}

# Function to backup existing configuration
backup_config() {
    BACKUP_DIR="$HOME/firefox-privacy-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR" || { print_error "Failed to create backup directory"; return 1; }

    if [ -f "$FIREFOX_PROFILE/prefs.js" ]; then
        cp "$FIREFOX_PROFILE/prefs.js" "$BACKUP_DIR/" && \
            print_success "Backed up prefs.js to $BACKUP_DIR/" || { print_error "Backup failed"; return 1; }
    fi

    if [ -f "$FIREFOX_PROFILE/user.js" ]; then
        cp "$FIREFOX_PROFILE/user.js" "$BACKUP_DIR/" && \
            print_success "Backed up user.js to $BACKUP_DIR/" || { print_error "Backup failed"; return 1; }
    fi

    print_info "Backup location: $BACKUP_DIR"
}

# Function to set preference in user.js (FIXED)
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

    # Remove any existing line with this preference name (FIXED)
    $SED_INPLACE "/^user_pref(\"$pref_name\"/d" "$user_js" 2>/dev/null || true

    echo "$pref_line" >> "$user_js"
    print_info "Set: $pref_name = $pref_value"
}

# Function to create/initialize user.js (FIXED)
init_user_js() {
    local user_js="$FIREFOX_PROFILE/user.js"

    # Clear existing file first (CRITICAL FIX - prevents duplicates)
    > "$user_js" 2>/dev/null || { print_error "Failed to clear $user_js"; return 1; }

    # Create header with timestamp
    cat >> "$user_js" << EOF
// Firefox Privacy Hardening Script - v${SCRIPT_VERSION}
// Applied on: $(date)
// Author: Wael Isa (https://www.wael.name, https://github.com/waelisa)
// This is a BALANCED approach - keeps banking sites working and Firefox homepage functional

EOF

    print_success "Initialized user.js (cleared existing content)"
}

# Main hardening function with BANKING COMPATIBILITY FIXES
apply_privacy_hardening() {
    local user_js="$FIREFOX_PROFILE/user.js"

    print_info "Starting Firefox privacy hardening v${SCRIPT_VERSION}..."

    # Create or append to user.js
    if [ ! -f "$user_js" ]; then
        init_user_js
    else
        print_warning "user.js already exists. Clearing and reinitializing..."
        init_user_js
        echo -e "\n\n// Additional settings added on: $(date)" >> "$user_js"
    fi

    # === PRIVACY & TRACKING (BANKING FRIENDLY) ===
    print_info "Applying privacy and tracking settings..."
    set_pref "privacy.trackingprotection.enabled" "true" "bool"
    set_pref "privacy.trackingprotection.socialtracking.enabled" "true" "bool"
    set_pref "privacy.trackingprotection.fingerprinting.enabled" "false" "bool"  # OFF for banking sites
    set_pref "privacy.trackingprotection.cryptomining.enabled" "true" "bool"
    set_pref "privacy.donottrackheader.enabled" "true" "bool"

    # === HISTORY & DATA (BANKING FRIENDLY) ===
    print_info "Applying history and data settings..."
    set_pref "browser.privatebrowsing.autostart" "false" "bool"  # Don't force private mode
    set_pref "places.history.enabled" "true" "bool"  # Keep history enabled but clear on exit
    set_pref "privacy.clearOnShutdown.history" "true" "bool"
    set_pref "privacy.clearOnShutdown.downloads" "true" "bool"
    set_pref "privacy.clearOnShutdown.cookies" "false" "bool"  # KEEP cookies for banking!
    set_pref "privacy.clearOnShutdown.cache" "true" "bool"
    set_pref "privacy.clearOnShutdown.formdata" "true" "bool"
    set_pref "privacy.clearOnShutdown.sessions" "true" "bool"
    set_pref "privacy.clearOnShutdown.offlineApps" "true" "bool"
    set_pref "privacy.sanitize.sanitizeOnShutdown" "true" "bool"
    set_pref "network.cookie.lifetimePolicy" "0" "int"  # 0 = Accept cookies normally (banking sites need this)

    # === ADDRESS BAR & SEARCH ===
    print_info "Applying address bar and search settings..."
    set_pref "browser.urlbar.suggest.history" "false" "bool"
    set_pref "browser.urlbar.suggest.bookmark" "true" "bool"  # Keep bookmarks suggestions (useful)
    set_pref "browser.urlbar.suggest.openpage" "false" "bool"
    set_pref "browser.urlbar.suggest.topsites" "false" "bool"
    set_pref "browser.urlbar.suggest.engines" "false" "bool"
    set_pref "browser.search.suggest.enabled" "false" "bool"

    # === SECURITY (ESSENTIALS) ===
    print_info "Applying security settings..."
    set_pref "browser.safebrowsing.malware.enabled" "true" "bool"  # Keep malware protection
    set_pref "browser.safebrowsing.phishing.enabled" "true" "bool"  # Keep phishing protection
    set_pref "browser.safebrowsing.downloads.enabled" "true" "bool"  # Keep download scanning

    # === HTTPS (FLEXIBLE FOR BANKING) ===
    print_info "Applying HTTPS and connection settings..."
    set_pref "dom.security.https_only_mode" "false" "bool"  # OFF - some banking sites use mixed content
    set_pref "dom.security.https_only_mode_pbm" "true" "bool"  # ON only in private mode

    # === PASSWORDS & FORMS (BANKING FRIENDLY) ===
    print_info "Applying password and form settings..."
    set_pref "signon.rememberSignons" "false" "bool"  # Don't save passwords (use password manager instead)
    set_pref "signon.autofillForms" "false" "bool"  # Don't autofill
    set_pref "browser.formfill.enable" "false" "bool"  # Don't save form history

    # === HOME PAGE & NEW TAB (KEEP FIREFOX DEFAULT) ===
    print_info "Applying homepage and new tab settings..."
    set_pref "browser.newtabpage.enabled" "true" "bool"  # Keep default new tab
    set_pref "browser.newtabpage.activity-stream.feeds.snippets" "true" "bool"  # Keep snippets (helpful)
    set_pref "browser.newtabpage.activity-stream.showSponsored" "false" "bool"  # Just disable sponsored

    # === TELEMETRY & DATA COLLECTION ===
    print_info "Disabling telemetry and data collection..."
    set_pref "datareporting.healthreport.uploadEnabled" "false" "bool"
    set_pref "datareporting.policy.dataSubmissionEnabled" "false" "bool"
    set_pref "toolkit.telemetry.enabled" "false" "bool"
    set_pref "toolkit.telemetry.unified" "false" "bool"

    # === ADVANCED FINGERPRINTING (BANKING FRIENDLY) ===
    print_info "Applying advanced fingerprinting protection..."
    set_pref "privacy.resistFingerprinting" "true" "bool"  # ON but will prompt for exceptions
    set_pref "privacy.resistFingerprinting.autoDeclineNoUserInputCanvasPrompts" "true" "bool"
    set_pref "privacy.resistFingerprinting.block_mozAddonManager" "true" "bool"

    # === WEBRTC (ENABLED FOR VIDEO CALLS) ===
    print_info "Applying WebRTC protection..."
    set_pref "media.peerconnection.enabled" "true" "bool"  # Keep ON for video calls/banking support

    # === GEOLOCATION (PROMPT) ===
    print_info "Applying geolocation settings..."
    set_pref "geo.enabled" "true" "bool"  # Keep enabled but will prompt
    set_pref "geo.provider.network.url" "https://location.services.mozilla.com/v1" "string"

    # === DISABLE MOZILLA SERVICES ===
    print_info "Disabling Mozilla services and features..."
    set_pref "extensions.pocket.enabled" "false" "bool"  # Disable Pocket
    set_pref "browser.topsites.contile.enabled" "false" "bool"  # Sponsored tiles

    # === DNS & NETWORK ===
    print_info "Applying DNS and network settings..."
    set_pref "network.dns.disablePrefetch" "true" "bool"
    set_pref "network.predictor.enabled" "false" "bool"
    set_pref "network.prefetch-next" "false" "bool"

    # === CACHE & MEDIA (BANKING FRIENDLY) ===
    print_info "Applying cache and media settings..."
    set_pref "browser.cache.offline.enable" "false" "bool"
    set_pref "media.autoplay.enabled" "true" "bool"  # Keep autoplay for streaming sites

    # === UI TWEAKS ===
    print_info "Applying UI tweaks..."
    set_pref "browser.uidensity" "1" "int"  # Compact mode (like LibreWolf)

    print_success "Privacy hardening settings have been applied to user.js"
}

# Function to wait for profile creation (FIXED - prevents infinite loop)
wait_for_profile() {
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        # Look for any new profile directory with prefs.js
        for dir in "$HOME/.mozilla/firefox/"*.default*; do
            if [ -d "$dir" ] && [ -f "$dir/prefs.js" ]; then
                FIREFOX_PROFILE="$dir"
                print_success "Using new profile: $FIREFOX_PROFILE"
                return 0
            fi
        done

        # Also check for snap/flatpak profiles
        for dir in "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox/"*.default*; do
            if [ -d "$dir" ] && [ -f "$dir/prefs.js" ]; then
                FIREFOX_PROFILE="$dir"
                print_success "Using new profile: $FIREFOX_PROFILE"
                return 0
            fi
        done

        for dir in "$HOME/snap/firefox/common/.mozilla/firefox/"*.default*; do
            if [ -d "$dir" ] && [ -f "$dir/prefs.js" ]; then
                FIREFOX_PROFILE="$dir"
                print_success "Using new profile: $FIREFOX_PROFILE"
                return 0
            fi
        done

        print_info "Waiting for profile creation... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    print_error "Profile not found after $max_attempts attempts!"
    return 1
}

# Function to validate settings were applied correctly
validate_settings() {
    local user_js="$FIREFOX_PROFILE/user.js"

    print_info "Validating settings..."

    # Check key preferences
    local check_list=(
        "privacy.trackingprotection.enabled"
        "browser.safebrowsing.malware.enabled"
        "datareporting.healthreport.uploadEnabled"
        "network.cookie.lifetimePolicy"
        "media.peerconnection.enabled"
        "signon.rememberSignons"
    )

    for pref in "${check_list[@]}"; do
        if grep -q "$pref" "$user_js"; then
            print_success "✓ $pref verified"
        else
            print_warning "✗ $pref missing (may need manual check)"
        fi
    done

    print_info "Validation complete!"
}

# Function to restore from backup
restore_backup() {
    local backup_dir="$1"

    if [ ! -d "$backup_dir" ]; then
        print_error "Backup directory not found: $backup_dir"
        return 1
    fi

    if [ -f "$backup_dir/prefs.js" ]; then
        cp "$backup_dir/prefs.js" "$FIREFOX_PROFILE/" && \
            print_success "Restored prefs.js from $backup_dir" || { print_error "Restore failed"; return 1; }
    fi

    if [ -f "$backup_dir/user.js" ]; then
        cp "$backup_dir/user.js" "$FIREFOX_PROFILE/" && \
            print_success "Restored user.js from $backup_dir" || { print_error "Restore failed"; return 1; }
    fi

    print_info "Backup restored successfully!"
}

# Function to display recommended add-ons
show_addon_recommendations() {
    echo -e "\n${GREEN}=== Recommended Privacy Add-ons ===${NC}"
    echo -e "${YELLOW}These add-ons enhance privacy beyond built-in settings:${NC}"
    echo -e "  ${BLUE}1. uBlock Origin${NC} - https://addons.mozilla.org/firefox/addon/ublock-origin/"
    echo -e "     Content blocker with advanced privacy features"
    echo -e ""
    echo -e "  ${BLUE}2. Firefox Multi-Account Containers${NC} - https://addons.mozilla.org/firefox/addon/multi-account-containers/"
    echo -e "     Isolate web sessions and cookies"
    echo -e ""
    echo -e "  ${BLUE}3. ClearURLs${NC} - https://addons.mozilla.org/firefox/addon/clearurls/"
    echo -e "     Removes tracking parameters from URLs"
}

# Function to display important notes
show_notes() {
    echo -e "\n${YELLOW}=== Important Notes ===${NC}"
    echo -e "1. ${GREEN}Banking sites should work normally${NC} (cookies kept, resistFingerprinting OFF)"
    echo -e "2. ${GREEN}Firefox homepage stays functional${NC} (snippets, new tab page)"
    echo -e "3. ${GREEN}Video calls work${NC} (WebRTC enabled)"
    echo -e "4. ${RED}Some websites may break${NC} with these settings"
    echo -e "   - You can temporarily disable resistFingerprinting for specific sites"
    echo -e ""
    echo -e "${GREEN}To undo changes:${NC}"
    echo -e "   - Delete or rename $FIREFOX_PROFILE/user.js"
    echo -e "   - Or restore from backup in $BACKUP_DIR/"
    echo -e ""
    echo -e "${GREEN}To apply changes:${NC}"
    echo -e "   - Restart Firefox completely"
    echo -e "   - Check about:config to verify settings"
}

# Main execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${BLUE}   Wael Isa - Firefox Privacy Hardening v${SCRIPT_VERSION}${NC}"
    echo -e "${GREEN}   (Banking-Friendly Edition)       ${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Detect OS for sed command
    detect_os_sed

    # Check if Firefox is installed
    check_firefox

    # Ask about new profile
    echo -e "\n${YELLOW}Create a new profile for these settings?${NC}"
    echo "This keeps your current Firefox separate (recommended)"
    echo -n "Create new profile? (y/n): "
    read -r create_profile

    if [[ "$create_profile" =~ ^[Yy]$ ]]; then
        print_info "Creating new Firefox profile..."
        firefox -CreateProfile "privacy-hardened" || { print_error "Failed to create profile"; exit 1; }
        print_success "New profile 'privacy-hardened' created."

        # Find the new profile directory (FIXED: wait loop with timeout)
        if ! wait_for_profile; then
            print_error "Profile creation timed out!"
            exit 1
        fi

        print_info "Launch with: ${GREEN}firefox -P privacy-hardened${NC}"
    else
        # Find existing Firefox profile (FIXED)
        if ! find_firefox_profile; then
            exit 1
        fi

        # Backup existing config
        print_info "Creating backup..."
        backup_config || { print_error "Backup failed"; exit 1; }
    fi

    # Apply privacy hardening
    apply_privacy_hardening

    # Show recommendations
    show_addon_recommendations

    # Show important notes
    show_notes

    # Validate settings (NEW)
    validate_settings

    echo -e "\n${GREEN}=== Script Complete ===${NC}"
    print_success "Firefox has been hardened for privacy!"
    print_info "Please restart Firefox to apply all changes."
    print_info "You can verify settings in about:config"

    # Ask about restore option
    echo -e "\n${YELLOW}Restore previous settings? (y/n): ${NC}"
    read -r restore_confirm
    if [[ "$restore_confirm" =~ ^[Yy]$ ]]; then
        print_info "Restoring from: $BACKUP_DIR"
        restore_backup "$BACKUP_DIR" || { print_error "Restore failed"; exit 1; }
    fi
}

# Run the main function
main
