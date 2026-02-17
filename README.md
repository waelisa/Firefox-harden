# Firefox-harden
How to Use This Script

    Download the script:

bash

wget https://github.com/waelisa/Firefox-harden/raw/refs/heads/main/firefox-harden.sh

    Make it executable:

bash

chmod +x firefox-harden.sh

    Run the script:

bash

./firefox-harden.sh

What This Script Does
🛡️ Comprehensive Privacy Hardening

The script modifies over 100 Firefox preferences across multiple categories:
Category	Key Changes
Privacy & Tracking	Enables all tracking protection features
History & Data	Clears everything on shutdown, disables session restore
Address Bar	Disables all suggestions (history, bookmarks, etc.)
Security	Enables safe browsing but disables remote lookups
HTTPS	Forces HTTPS-only mode everywhere
Passwords	Disables password saving and autofill completely
Home/New Tab	Removes all sponsored content and suggestions
Telemetry	Completely disables all Mozilla data collection
Fingerprinting	Enables resistFingerprinting and letterboxing
WebRTC	Prevents IP leaks by disabling WebRTC
Geolocation	Disables all location services
Mozilla Services	Disables Pocket, sponsored tiles, etc.
Network	Disables prefetching, preloading, speculative connections
Extensions	Restricts extension installation sources
📁 Backup Creation

    Automatically creates timestamped backups of your existing prefs.js and user.js

    Backup location: ~/firefox-privacy-backup-YYYYMMDD-HHMMSS/

🔧 Profile Management Options

    Option to create a new dedicated "privacy-hardened" profile

    Keeps your existing Firefox configuration separate

    Launch with: firefox -P privacy-hardened

📋 Additional Features

    Add-on recommendations with direct links to Mozilla Add-ons

    Important notes about potential breakage and how to handle it

    Verification instructions to check settings in about:config

    Colored output for better readability

Important Notes

⚠️ Potential Breakage: The privacy.resistFingerprinting setting (enabled by this script) is the most aggressive privacy feature. It may cause:

    Websites to display incorrectly

    Some functionality to break

    Date/time to appear in UTC

    Fonts to be limited

🔧 If websites break, you can:

    Temporarily disable resistFingerprinting for that site

    Create site-specific exceptions in about:config

    Use Firefox Multi-Account Containers to isolate problematic sites

🎬 Streaming Services: Netflix, Hulu, etc. may not work due to:

    DRM being effectively disabled

    Cookies being cleared on exit

    You may need to enable DRM and keep cookies for specific streaming domains

Verification

After running the script and restarting Firefox:

    Type about:config in the address bar

    Search for any of the preferences set by the script

    Verify they match the values in the script

Undo Changes

To revert to your previous settings:

    Delete the user.js file from your profile directory

    Or restore from the backup created by the script:

bash

cp ~/firefox-privacy-backup-*/prefs.js ~/.mozilla/firefox/*.default*/prefs.js

This script gives you the same privacy level as LibreWolf while keeping the flexibility of standard Firefox. The extensive comments and organization make it easy to understand what each setting does and modify it if needed.




ifferences from the Heavy Version
✅ Banking-Friendly Features:

    Cookies are KEPT (network.cookie.lifetimePolicy=0) - Banking sessions persist

    resistFingerprinting is OFF - This feature breaks many banking sites

    HTTPS-only mode is OFF - Some banking sites use mixed content

    WebRTC is ON - Needed for bank video verification

    Geolocation is ON (but prompts) - Some banks use location for fraud detection

✅ Firefox Homepage Works:

    New tab page stays functional

    Snippets remain enabled (helpful Firefox tips)

    Only sponsored content is disabled

✅ Balanced Privacy:

    Tracking protection is ON (but fingerprinting protection is OFF)

    History cleared on shutdown

    Telemetry disabled

    Search suggestions disabled

    Prefetching disabled

    Password saving disabled

🔧 What's Protected vs What's Usable:
Feature	Setting	Why
Cookies	Kept	Banking login persistence
resistFingerprinting	OFF	Prevents banking site breakage
HTTPS-only	OFF (private mode only)	Some banks use HTTP for parts of site
WebRTC	ON	Video verification for banks
Tracking Protection	ON	Blocks trackers safely
History	Cleared on shutdown	Privacy without breaking functionality
New Tab Page	Default	Keeps Firefox familiar
📝 Usage Instructions:

    Save as firefox-lite-harden.sh

    chmod +x firefox-lite-harden.sh

    ./firefox-lite-harden.sh

    Choose to create a new profile (recommended)

    Restart Firefox

🏦 For Banking Sites:

The script creates a perfect balance - your banking sessions will persist, 2FA will work, video verification will function, and you won't get constantly logged out.
🎯 Recommended Add-ons:

The script suggests add-ons that enhance privacy without breaking banking sites:

    Multi-Account Containers - Isolate your banking in its own container

    uBlock Origin - Use in medium mode (blocks ads but not site functionality)

    ClearURLs - Removes tracking parameters safely

This lite version gives you about 80% of the privacy benefits with 0% of the banking-site headaches!

[Donate link – PayPal](https://www.paypal.me/WaelIsa)

