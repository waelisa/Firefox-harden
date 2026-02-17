#!/bin/bash

#############################################################################################################################
# The MIT License (MIT)
# Wael Isa
# Build Date: 02/18/2026
# Version: 3.0.0
# https://github.com/waelisa/firefox-harden
#############################################################################################################################
# Firefox to LibreWolf Privacy Hardening Script
# Transforms Firefox into a privacy-focused browser (LibreWolf-like)
# Features:
#   ✓ Comprehensive privacy hardening (LibreWolf-level)
#   ✓ Multi-platform support (Native, Flatpak, Snap)
#   ✓ Automatic profile detection using profiles.ini
#   ✓ Safe backup creation before modifications
#   ✓ User overrides support (user-overrides.js)
#   ✓ Advanced fingerprinting protection
#   ✓ WebRTC leak prevention
#   ✓ DNS over HTTPS (DoH) configuration
#   ✓ Telemetry and data collection blocking
#   ✓ Letterboxing with pre-defined dimensions
#   ✓ New profile creation option
#############################################################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory for finding user-overrides.js
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Function to check if Firefox is installed
check_firefox() {
    if ! command -v firefox &> /dev/null; then
        print_error "Firefox is not installed. Please install Firefox first."
        exit 1
    fi
    print_success "Firefox found: $(firefox --version)"
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

# Function to find Firefox profile directory using profiles.ini
find_firefox_profile() {
    local profile_found=false
    local firefox_dir=""
    local profile_path=""

    # Check standard locations for profiles.ini
    local possible_dirs=(
        "$HOME/.mozilla/firefox"
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"  # Flatpak
        "$HOME/snap/firefox/common/.mozilla/firefox"  # Snap
    )

    for dir in "${possible_dirs[@]}"; do
        if [ -f "$dir/profiles.ini" ]; then
            firefox_dir="$dir"
            print_info "Found Firefox profiles.ini at: $firefox_dir/profiles.ini"

            # Extract the path of the default profile
            # First try to find profile marked as Default=1
            local in_profile=false
            local current_profile=""
            local is_default=false

            while IFS= read -r line; do
                if [[ $line =~ ^\[Profile[0-9]+\] ]]; then
                    # Start of a new profile section
                    in_profile=true
                    current_profile=""
                    is_default=false
                elif [[ $in_profile == true ]]; then
                    if [[ $line =~ ^Path=(.+)$ ]]; then
                        current_profile="${BASH_REMATCH[1]}"
                    elif [[ $line =~ ^Default=1$ ]]; then
                        is_default=true
                    elif [[ $line =~ ^\[.*\] ]]; then
                        # End of profile section
                        if [[ $is_default == true ]] && [[ -n $current_profile ]]; then
                            profile_path="$current_profile"
                            break
                        fi
                        in_profile=false
                    fi
                fi
            done < "$dir/profiles.ini"

            # If no Default=1 found, take the first profile
            if [[ -z $profile_path ]]; then
                profile_path=$(grep '^Path=' "$dir/profiles.ini" | head -n1 | cut -d'=' -f2)
            fi

            if [[ -n $profile_path ]]; then
                FIREFOX_PROFILE="$firefox_dir/$profile_path"
                if [ -d "$FIREFOX_PROFILE" ]; then
                    profile_found=true
                    print_success "Found Firefox profile: $FIREFOX_PROFILE"
                    break
                fi
            fi
        fi
    done

    # Fallback to wildcard search if profiles.ini method fails
    if [ "$profile_found" = false ]; then
        print_warning "profiles.ini method failed, falling back to wildcard search..."
        local fallback_dirs=(
            "$HOME/.mozilla/firefox/*.default*"
            "$HOME/.mozilla/firefox/*.default-release*"
            "$HOME/.mozilla/firefox/*.dev-edition-default*"
            "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox/*.default*"
            "$HOME/snap/firefox/common/.mozilla/firefox/*.default*"
        )

        for pattern in "${fallback_dirs[@]}"; do
            for dir in $pattern; do
                if [ -d "$dir" ] && [ -f "$dir/prefs.js" ]; then
                    FIREFOX_PROFILE="$dir"
                    profile_found=true
                    print_success "Found Firefox profile (fallback): $FIREFOX_PROFILE"
                    break 2
                fi
            done
        done
    fi

    if [ "$profile_found" = false ]; then
        print_error "Could not find Firefox profile directory."
        print_info "Please start Firefox at least once to create a profile."
        exit 1
    fi
}

# Function to backup existing configuration
backup_config() {
    local backup_dir="$HOME/firefox-privacy-backup-$(date +%Y%m%d-%H%M%S)"
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

# Function to check for and apply user overrides
apply_user_overrides() {
    local user_js="$FIREFOX_PROFILE/user.js"
    local override_file="$SCRIPT_DIR/user-overrides.js"

    if [ -f "$override_file" ]; then
        print_info "Found user-overrides.js in script directory"
        echo -e "\n\n// ===== USER OVERRIDES =====\n" >> "$user_js"
        cat "$override_file" >> "$user_js"
        print_success "Applied user overrides from $override_file"
    else
        print_info "No user-overrides.js found (optional - create one for custom settings)"
    fi
}

# Function to create/initialize user.js
init_user_js() {
    local user_js="$FIREFOX_PROFILE/user.js"

    # Create header with timestamp and author info
    cat > "$user_js" << EOF
// Firefox Privacy Hardening Script
// Author: Wael Isa
// GitHub: https://github.com/waelisa/firefox-harden
// Version: 3.0.0
// Applied on: $(date)
// This file overrides Firefox's default settings for enhanced privacy

// ==================== WARNING ====================
// These settings significantly harden Firefox for privacy
// Some websites may not work correctly with all settings enabled
// You may need to adjust certain preferences for specific sites
// =================================================

EOF

    print_success "Initialized user.js"
}

# Main hardening function
apply_privacy_hardening() {
    local user_js="$FIREFOX_PROFILE/user.js"

    print_info "Starting Firefox privacy hardening..."

    # Create or append to user.js
    if [ ! -f "$user_js" ]; then
        init_user_js
    else
        print_warning "user.js already exists. New settings will be appended."
        echo -e "\n\n// ===== Additional settings added on: $(date) =====\n" >> "$user_js"
    fi

    # === PRIVACY & TRACKING ===
    print_info "Applying privacy and tracking settings..."
    set_pref "privacy.trackingprotection.enabled" "true" "bool"
    set_pref "privacy.trackingprotection.socialtracking.enabled" "true" "bool"
    set_pref "privacy.trackingprotection.fingerprinting.enabled" "true" "bool"
    set_pref "privacy.trackingprotection.cryptomining.enabled" "true" "bool"
    set_pref "privacy.trackingprotection.pbmode.enabled" "true" "bool"
    set_pref "privacy.donottrackheader.enabled" "true" "bool"
    set_pref "privacy.donottrackheader.value" "1" "int"

    # === HISTORY & DATA ===
    print_info "Applying history and data settings..."
    set_pref "browser.privatebrowsing.autostart" "false" "bool"  # Don't force private mode
    set_pref "places.history.enabled" "true" "bool"  # Keep history enabled but clear on exit
    set_pref "privacy.clearOnShutdown.history" "true" "bool"
    set_pref "privacy.clearOnShutdown.downloads" "true" "bool"
    set_pref "privacy.clearOnShutdown.cookies" "true" "bool"
    set_pref "privacy.clearOnShutdown.cache" "true" "bool"
    set_pref "privacy.clearOnShutdown.formdata" "true" "bool"
    set_pref "privacy.clearOnShutdown.sessions" "true" "bool"
    set_pref "privacy.clearOnShutdown.offlineApps" "true" "bool"
    set_pref "privacy.clearOnShutdown.siteSettings" "false" "bool"  # Keep site settings
    set_pref "privacy.sanitize.sanitizeOnShutdown" "true" "bool"
    set_pref "network.cookie.lifetimePolicy" "2" "int"  # 2 = delete on exit
    set_pref "browser.sessionstore.max_tabs_undo" "0" "int"
    set_pref "browser.sessionstore.max_windows_undo" "0" "int"
    set_pref "browser.sessionstore.interval" "15000000" "int"  # 4+ hours

    # === ADDRESS BAR & SEARCH ===
    print_info "Applying address bar and search settings..."
    set_pref "browser.urlbar.suggest.history" "false" "bool"
    set_pref "browser.urlbar.suggest.bookmark" "false" "bool"
    set_pref "browser.urlbar.suggest.openpage" "false" "bool"
    set_pref "browser.urlbar.suggest.topsites" "false" "bool"
    set_pref "browser.urlbar.suggest.engines" "false" "bool"
    set_pref "browser.search.suggest.enabled" "false" "bool"
    set_pref "browser.search.separatePrivateDefault.ui.enabled" "true" "bool"
    set_pref "browser.search.separatePrivateDefault" "true" "bool"
    set_pref "browser.search.separatePrivateDefault.urlbarResult.enabled" "true" "bool"

    # === SECURITY ===
    print_info "Applying security settings..."
    set_pref "browser.safebrowsing.malware.enabled" "true" "bool"
    set_pref "browser.safebrowsing.phishing.enabled" "true" "bool"
    set_pref "browser.safebrowsing.downloads.enabled" "true" "bool"
    set_pref "browser.safebrowsing.downloads.remote.enabled" "false" "bool"  # Disable remote lookups
    set_pref "browser.safebrowsing.downloads.remote.url" "" "string"
    set_pref "browser.safebrowsing.downloads.remote.block_potentially_unwanted" "true" "bool"
    set_pref "browser.safebrowsing.downloads.remote.block_uncommon" "true" "bool"

    # === HTTPS & CONNECTIONS ===
    print_info "Applying HTTPS and connection settings..."
    set_pref "dom.security.https_only_mode" "true" "bool"
    set_pref "dom.security.https_only_mode_pbm" "true" "bool"
    set_pref "dom.security.https_only_mode_send_http_background_request" "false" "bool"
    set_pref "dom.security.https_only_mode_errors" "user-friendly" "string"
    set_pref "network.trr.mode" "2" "int"  # 2 = Use DoH with fallback
    set_pref "network.trr.uri" "https://mozilla.cloudflare-dns.com/dns-query" "string"
    set_pref "network.trr.custom_uri" "" "string"
    set_pref "network.trr.bootstrapAddr" "" "string"

    # === PASSWORDS & FORMS ===
    print_info "Applying password and form settings..."
    set_pref "signon.rememberSignons" "false" "bool"
    set_pref "signon.autofillForms" "false" "bool"
    set_pref "signon.rememberSignons.visibilityToggle" "false" "bool"
    set_pref "signon.formlessCapture.enabled" "false" "bool"
    set_pref "signon.privateBrowsingOnly" "true" "bool"
    set_pref "browser.formfill.enable" "false" "bool"
    set_pref "extensions.formautofill.addresses.enabled" "false" "bool"
    set_pref "extensions.formautofill.creditCards.enabled" "false" "bool"
    set_pref "extensions.formautofill.heuristics.enabled" "false" "bool"

    # === HOME PAGE & NEW TAB ===
    print_info "Applying homepage and new tab settings..."
    set_pref "browser.newtabpage.enabled" "false" "bool"
    set_pref "browser.newtabpage.activity-stream.feeds.section.topstories" "false" "bool"
    set_pref "browser.newtabpage.activity-stream.feeds.snippets" "false" "bool"
    set_pref "browser.newtabpage.activity-stream.feeds.topsites" "false" "bool"
    set_pref "browser.newtabpage.activity-stream.feeds.telemetry" "false" "bool"
    set_pref "browser.newtabpage.activity-stream.prerender" "false" "bool"
    set_pref "browser.newtabpage.activity-stream.showSponsored" "false" "bool"
    set_pref "browser.newtabpage.activity-stream.showSponsoredTopSites" "false" "bool"
    set_pref "browser.newtabpage.activity-stream.default.sites" "" "string"
    set_pref "browser.newtabpage.pinned" "[]" "string"

    # === UI CLEANUP - REMOVE INTRUSIVE ELEMENTS ===
    print_info "Removing intrusive UI elements..."
    set_pref "browser.tabs.firefox-view" "false" "bool"  # Disable Firefox View button
    set_pref "browser.shopping.experience2023.enabled" "false" "bool"  # Disable shopping sidebar

    # === TELEMETRY & DATA COLLECTION ===
    print_info "Disabling telemetry and data collection..."
    set_pref "datareporting.healthreport.uploadEnabled" "false" "bool"
    set_pref "datareporting.policy.dataSubmissionEnabled" "false" "bool"
    set_pref "datareporting.sessions.current.clean" "true" "bool"
    set_pref "devtools.onboarding.telemetry.logged" "false" "bool"
    set_pref "toolkit.telemetry.updatePing.enabled" "false" "bool"
    set_pref "browser.ping-centre.telemetry" "false" "bool"
    set_pref "toolkit.telemetry.enabled" "false" "bool"
    set_pref "toolkit.telemetry.unified" "false" "bool"
    set_pref "toolkit.telemetry.server" "data:," "string"
    set_pref "toolkit.telemetry.archive.enabled" "false" "bool"
    set_pref "toolkit.telemetry.bhrPing.enabled" "false" "bool"
    set_pref "toolkit.telemetry.cachedClientID" "" "string"
    set_pref "toolkit.telemetry.firstShutdownPing.enabled" "false" "bool"
    set_pref "toolkit.telemetry.hybridContent.enabled" "false" "bool"
    set_pref "toolkit.telemetry.newProfilePing.enabled" "false" "bool"
    set_pref "toolkit.telemetry.reportingpolicy.firstRun" "false" "bool"
    set_pref "toolkit.telemetry.shutdownPingSender.enabled" "false" "bool"

    # === ADVANCED FINGERPRINTING PROTECTION ===
    print_info "Applying advanced fingerprinting protection (may break some sites)..."
    set_pref "privacy.resistFingerprinting" "true" "bool"
    set_pref "privacy.resistFingerprinting.autoDeclineNoUserInputCanvasPrompts" "true" "bool"
    set_pref "privacy.resistFingerprinting.block_mozAddonManager" "true" "bool"
    set_pref "privacy.resistFingerprinting.exemptedDomains" "" "string"
    set_pref "privacy.resistFingerprinting.letterboxing" "true" "bool"  # LibreWolf feature
    set_pref "privacy.resistFingerprinting.letterboxing.dimensions" "1280x720, 1920x1080, 1366x768, 1536x864, 1440x900" "string"

    # === WEBRTC PROTECTION ===
    print_info "Applying WebRTC protection..."
    set_pref "media.peerconnection.enabled" "false" "bool"
    set_pref "media.peerconnection.ice.default_address_only" "true" "bool"
    set_pref "media.peerconnection.ice.no_host" "true" "bool"
    set_pref "media.peerconnection.ice.proxy_only_if_behind_proxy" "true" "bool"
    set_pref "media.peerconnection.ice.relay_only" "false" "bool"

    # === GEOLOCATION ===
    print_info "Applying geolocation settings..."
    set_pref "geo.enabled" "false" "bool"
    set_pref "geo.provider.network.url" "https://location.services.mozilla.com/v1" "string"
    set_pref "geo.provider.ms-windows-location" "false" "bool"  # Windows
    set_pref "geo.provider.use_corelocation" "false" "bool"  # macOS
    set_pref "geo.provider.use_gpsd" "false" "bool"  # Linux
    set_pref "geo.provider.vs.enabled" "false" "bool"
    set_pref "browser.region.network.url" "" "string"
    set_pref "browser.region.update.enabled" "false" "bool"

    # === DISABLE MOZILLA SERVICES ===
    print_info "Disabling Mozilla services and features..."
    set_pref "extensions.pocket.enabled" "false" "bool"
    set_pref "extensions.pocket.api" "" "string"
    set_pref "extensions.pocket.oAuthConsumerKey" "" "string"
    set_pref "extensions.pocket.site" "" "string"
    set_pref "browser.topsites.contile.enabled" "false" "bool"  # Sponsored tiles
    set_pref "browser.topsites.useRemoteSetting" "false" "bool"
    set_pref "browser.partnerlink.categories" "" "string"
    set_pref "browser.partnerlink.newwindow" "" "string"
    set_pref "browser.shell.checkDefaultBrowser" "false" "bool"
    set_pref "browser.shell.skipDefaultBrowserCheck" "true" "bool"

    # === DNS & NETWORK ===
    print_info "Applying DNS and network settings..."
    set_pref "network.dns.disablePrefetch" "true" "bool"
    set_pref "network.dns.disablePrefetchFromHTTPS" "true" "bool"
    set_pref "network.predictor.enabled" "false" "bool"
    set_pref "network.predictor.enable-prefetch" "false" "bool"
    set_pref "network.prefetch-next" "false" "bool"
    set_pref "network.preload" "false" "bool"
    set_pref "network.http.speculative-parallel-limit" "0" "int"
    set_pref "browser.urlbar.speculativeConnect.enabled" "false" "bool"

    # === CACHE & MEDIA ===
    print_info "Applying cache and media settings..."
    set_pref "browser.cache.offline.enable" "false" "bool"
    set_pref "browser.cache.offline.capacity" "0" "int"
    set_pref "media.autoplay.enabled" "false" "bool"
    set_pref "media.autoplay.default" "5" "int"  # 5 = Block audio/video
    set_pref "media.hardware-video-decoding.enabled" "false" "bool"  # Privacy vs performance
    set_pref "media.video_stats.enabled" "false" "bool"
    set_pref "media.webspeech.synth.enabled" "false" "bool"  # Speech synthesis

    # === EXTENSIONS ===
    print_info "Applying extension security settings..."
    set_pref "extensions.enabledScopes" "5" "int"  # Restrict installation locations
    set_pref "extensions.autoDisableScopes" "15" "int"
    set_pref "extensions.getAddons.showPane" "false" "bool"
    set_pref "extensions.htmlaboutaddons.recommendations.enabled" "false" "bool"
    set_pref "extensions.webservice.discoverURL" "" "string"

    # === UI TWEAKS ===
    print_info "Applying UI tweaks..."
    set_pref "browser.uidensity" "1" "int"  # Compact mode (like LibreWolf)
    set_pref "browser.tabs.drawInTitlebar" "true" "bool"
    set_pref "browser.tabs.unloadOnLowMemory" "true" "bool"

    # Apply user overrides if they exist
    apply_user_overrides

    # Set secure permissions on user.js
    chmod 640 "$user_js"

    print_success "Privacy hardening settings have been applied to user.js"
}

# Function to create a new profile
create_new_profile() {
    print_info "Would you like to create a new Firefox profile for these settings? (y/n)"
    echo "This keeps your current Firefox separate (recommended)"
    read -r create_profile

    if [[ "$create_profile" =~ ^[Yy]$ ]]; then
        print_info "Creating new Firefox profile..."
        firefox -CreateProfile "privacy-hardened"
        print_success "New profile 'privacy-hardened' created."

        # Find the new profile directory
        sleep 2
        local new_profile_dir="$HOME/.mozilla/firefox/*.privacy-hardened"
        for dir in $new_profile_dir; do
            if [ -d "$dir" ]; then
                FIREFOX_PROFILE="$dir"
                print_success "Using new profile: $FIREFOX_PROFILE"
                break
            fi
        done

        print_info "Launch with: ${GREEN}firefox -P privacy-hardened${NC}"
    else
        print_info "Using existing profile."
    fi
}

# Function to create a launcher script
create_launcher() {
    local launcher_dir="$HOME/.local/bin"
    mkdir -p "$launcher_dir"

    cat > "$launcher_dir/firefox-hardened" << EOF
#!/bin/bash
# Firefox Hardened Privacy Profile Launcher
# Created by Wael Isa's hardening script
firefox -P privacy-hardened "\$@"
EOF

    chmod +x "$launcher_dir/firefox-hardened"

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo -e "\n${YELLOW}Add this to your ~/.bashrc or ~/.zshrc:${NC}"
        echo 'export PATH="$HOME/.local/bin:$PATH"'
    fi

    print_success "Created launcher: $launcher_dir/firefox-hardened"
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
    echo -e "  ${BLUE}3. Temporary Containers${NC} - https://addons.mozilla.org/firefox/addon/temporary-containers/"
    echo -e "     Automatically isolate tabs in containers"
    echo -e ""
    echo -e "  ${BLUE}4. Privacy Badger${NC} - https://addons.mozilla.org/firefox/addon/privacy-badger17/"
    echo -e "     Learns to block invisible trackers"
    echo -e ""
    echo -e "  ${BLUE}5. CanvasBlocker${NC} - https://addons.mozilla.org/firefox/addon/canvasblocker/"
    echo -e "     Prevents canvas fingerprinting"
    echo -e ""
    echo -e "  ${BLUE}6. ClearURLs${NC} - https://addons.mozilla.org/firefox/addon/clearurls/"
    echo -e "     Removes tracking parameters from URLs"
    echo -e ""
    echo -e "  ${BLUE}7. Decentraleyes${NC} - https://addons.mozilla.org/firefox/addon/decentraleyes/"
    echo -e "     Local emulation of CDNs to prevent tracking"
}

# Function to display important notes
show_notes() {
    echo -e "\n${YELLOW}=== Important Notes ===${NC}"
    echo -e "1. ${RED}Some websites may break${NC} with these settings (especially resistFingerprinting)"
    echo -e "   - You can temporarily disable resistFingerprinting for specific sites"
    echo -e "   - Or create site-specific exceptions in about:config"
    echo -e ""
    echo -e "2. ${RED}Streaming services${NC} (Netflix, Hulu, etc.) may require:"
    echo -e "   - Enabling DRM (digitalrightsmanager)"
    echo -e "   - Allowing cookies for the specific streaming site"
    echo -e ""
    echo -e "3. ${RED}WebRTC is disabled${NC} (video calls may not work)"
    echo -e "   - If you need WebRTC, set media.peerconnection.enabled back to true"
    echo -e ""
    echo -e "4. ${RED}Geolocation is disabled${NC} - websites cannot detect your location"
    echo -e ""
    echo -e "5. ${GREEN}User Overrides Support${NC}:"
    echo -e "   - Create a file named 'user-overrides.js' in the script directory"
    echo -e "   - Any settings in that file will be appended after hardening"
    echo -e "   - Perfect for custom exceptions that survive script re-runs"
    echo -e ""
    echo -e "6. ${GREEN}To undo changes${NC}:"
    echo -e "   - Delete or rename $FIREFOX_PROFILE/user.js"
    echo -e "   - Or restore from backup in $HOME/firefox-privacy-backup-*/"
    echo -e ""
    echo -e "7. ${GREEN}To apply changes${NC}:"
    echo -e "   - Restart Firefox completely"
    echo -e "   - Check about:config to verify settings"
}

# Main execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Firefox to LibreWolf Privacy Hardening   ${NC}"
    echo -e "${GREEN}   Author: Wael Isa                         ${NC}"
    echo -e "${GREEN}   Version: 3.0.0                           ${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Check if Firefox is installed
    check_firefox

    # Check if Firefox is running
    check_firefox_running

    # Ask about new profile
    create_new_profile

    # Find Firefox profile
    find_firefox_profile

    # Backup existing config
    print_info "Creating backup..."
    backup_config

    # Apply privacy hardening
    apply_privacy_hardening

    # Create launcher if new profile was created
    if [[ "$create_profile" =~ ^[Yy]$ ]]; then
        create_launcher
    fi

    # Show recommendations
    show_addon_recommendations

    # Show important notes
    show_notes

    echo -e "\n${GREEN}=== Script Complete ===${NC}"
    print_success "Firefox has been hardened for privacy!"
    print_info "Please restart Firefox to apply all changes."
    print_info "You can verify settings in about:config"
}

# Run the main function
main
