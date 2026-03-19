🦊 Firefox Privacy Hardening Scripts  

📖 Overview

This repository contains two Bash scripts that automatically configure Firefox preferences via user.js to enhance privacy, security, and reduce telemetry.

firefox-harden.sh: Aggressive hardening for maximum privacy (may break some sites).

firefox-lite-harden.sh: Balanced hardening optimized for banking compatibility and daily use.

Both scripts include automatic profile detection, backup systems, validation checks, and restore options.

🚀 Quick Start

# Clone the repository
```bash
git clone https://github.com/waelisa/Firefox-harden.git

cd Firefox-harden
```
# Make executable
```bash
chmod +x firefox-harden.sh

chmod +x firefox-lite-harden.sh
```
# Run one of them
```bash
./firefox-lite-harden.sh # Recommended for daily use
```
# OR
```bash
./firefox-harden.sh # For maximum privacy
```
🏆 Which One Should You Choose?

Choose firefox-lite-harden.sh if:

✅ Banking compatibility is your top priority

✅ You need video calls to work (WebRTC)

✅ You prefer Firefox homepage functionality

✅ You want a balanced approach (privacy + usability)

Choose firefox-harden.sh if:

✅ You want maximum privacy above all else

✅ You don't mind some sites breaking occasionally

✅ You're comfortable adjusting settings manually for specific sites

✅ You use Firefox primarily for browsing, not banking/video calls

🛠️ Features (Both Scripts)

✅ Automatic Profile Detection: Works with Desktop, Flatpak, and Snap Firefox profiles.

✅ Backup System: Creates timestamped backups before applying changes.

✅ Validation System: Confirms all settings were applied correctly at the end.

✅ Restore Option: Allows reverting to backup after script completion.

✅ OS Compatibility: Auto-detects macOS vs Linux for sed -i command.

✅ Profile Creation Timeout: Prevents infinite loops when creating new profiles.

✅ Banking Friendly: Optimized settings to keep sessions persistent.

📝 Configuration Options

Dry Run Mode (Lite Version Only)

Preview changes before applying:
```bash
./firefox-lite-harden.sh --dry-run
```
Create New Profile

The script will ask if you want a new profile:

Yes: Creates privacy-hardened or privacy-lite profile.

No: Uses existing default profile.

🧪 Test Checklist After Running

After running either script, verify these work:

Open a banking website (should load normally)

Check Firefox homepage (snippets should appear in Lite version)

Try video call (WebRTC works in Lite version)

Verify privacy settings in about:config

Check backup folder exists at $HOME/firefox-\*-backup-\*

📂 File Structure

```bash

Firefox-harden/

├── firefox-harden.sh # Full aggressive hardening script

├── firefox-lite-harden.sh # Balanced banking-friendly script

└── README.md # This file
```

🔧 Troubleshooting

Script hangs on "Waiting for profile creation..."

Cause: Firefox is slow to create the new profile.

Fix: Wait up to 60 seconds (timeout limit). If it fails, restart script.

Banking site breaks after running firefox-harden.sh

Cause: Aggressive fingerprinting protection (resistFingerprinting = true).

Fix: Open about:config, search for privacy.resistFingerprinting, set to false.

Settings not applying

Cause: Firefox needs a full restart.

Fix: Close all Firefox windows completely, then reopen.

📜 Changelog

v2.1.0 (Latest)

✅ Fixed infinite loop on profile creation

✅ Added validation system to confirm settings applied

✅ Improved banking compatibility (cookies kept by default)

✅ OS detection for sed -i command (macOS/Linux)

v2.0.0

✅ Complete rewrite with enhanced privacy and profile detection

✅ Fixed infinite loop on profile creation, added timeout limit

v1.0.0

✅ Initial release

👤 Author

Wael Isa

🌐 Website: https://www.wael.name

📦 GitHub: https://github.com/waelisa

📧 Email: (See profile for contact)

📄 License

MIT License - See LICENSE file for details.

🔗 Links

Repository: https://github.com/waelisa/Firefox-harden

Issue Tracker: GitHub Issues

Firefox Docs: about:config Guide
