# **Firefox Privacy Suite (Lite & Extreme)**

A comprehensive privacy toolkit for Firefox. This repository provides two specialized scripts to harden your browser: **Lite** (for daily usability and banking) and **Extreme** (for maximum anonymity and data sovereignty).

## **📊 Choose Your Protection Level**

Feature

**Firefox-Lite-Harden**

**Firefox-Harden (Extreme)**

**Philosophy**

Privacy without breakage.

Maximum security "Fortress."

**Banking & PayPal**

✅ Works Out-of-box

⚠️ May trigger bot detection

**Video Calls (WebRTC)**

✅ Supported

❌ Disabled (VPN Leak protection)

**DRM (Netflix/Spotify)**

✅ Enabled

❌ Disabled by default

**Anti-Fingerprinting**

🛡️ Basic Protection

🔒 Strict (ResistFingerprinting)

**Visuals**

Standard

🏁 Letterboxed (Gray Borders)

Export to Sheets

## **🚀 Quick Start (One-Liners)**

### **Option 1: The "Daily Driver" (Lite)**

_Best for users who want to kill telemetry and ads but keep banking and video calls working._

Bash

wget -qO firefox-lite-harden.sh https://github.com/waelisa/Firefox-harden/raw/refs/heads/main/firefox-lite-harden.sh && chmod +x firefox-lite-harden.sh && ./firefox-lite-harden.sh

### **Option 2: The "Fortress" (Extreme)**

_Best for journalists, activists, or privacy enthusiasts who want to look identical to other hardened users._

Bash

wget -qO firefox-harden.sh https://github.com/waelisa/Firefox-harden/raw/refs/heads/main/firefox-harden.sh && chmod +x firefox-harden.sh && ./firefox-harden.sh

## **✨ Key Features (Both Scripts)**

*   **Zero Telemetry:** Kills all Mozilla data collection, health reports, and "studies."
*   **De-Bloat:** Removes Pocket, Sponsored Shortcuts, and the Firefox View button.
*   **Auto-Detection:** Automatically finds profiles for **Native**, **Flatpak**, and **Snap** installations.
*   **Profile Safety:** Offers to create a **new profile** so your original data remains untouched.
*   **Process Guard:** Checks if Firefox is running to prevent configuration corruption.

## **🛠 Manual Configuration**

Both scripts utilize a user.js file placed in your Firefox profile directory. This file overrides about:config settings every time the browser starts, ensuring your privacy settings are never "undone" by browser updates.

### **To Undo Changes:**

1.  Navigate to your profile folder (e.g., \~/.mozilla/firefox/[profile-name]).
2.  Delete the user.js file.
3.  Restart Firefox.

## **📈 Technical Comparisons**

### **Resist Fingerprinting (RFP)**

The **Extreme** script enables privacy.resistFingerprinting. This forces Firefox to use a generic screen resolution and UTC timezone. You will see "gray bars" around websites—this is a feature, not a bug! It prevents trackers from identifying you based on your monitor size.

### **WebRTC IP Leaks**

The **Lite** script leaves WebRTC on for Zoom/Teams. The **Extreme** script disables it entirely to prevent your real IP address from leaking through your VPN.

## **☕ Support the Project**

If these scripts help you take control of your digital footprint, consider supporting the work:

*   **GitHub:** [waelisa/Firefox-harden](https://github.com/waelisa/Firefox-harden))
*   **PayPal:** [Donate link – PayPal](https://www.paypal.me/WaelIsa)
*   **Blog:** [Wael.name](https://www.wael.name)
