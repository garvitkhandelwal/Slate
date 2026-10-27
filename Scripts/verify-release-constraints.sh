#!/bin/zsh
# Static release audit for Slate. Run from the repository root; exits nonzero on any violation.
set -euo pipefail

cd "${SRCROOT:-$(dirname "$0")/..}"
app_root="Slate"
mac_root="SlateMac"

# 1. No network, web, cloud, analytics, or telemetry APIs in either app target.
forbidden_source='URLSession|WKWebView|WebSocket|import CloudKit|import WebKit|Firebase|Amplitude|Segment|Sentry'
if grep -rnE "$forbidden_source" "$app_root" "$mac_root" --include='*.swift'; then
  print -u2 "forbidden network, web, cloud, or telemetry API found"
  exit 1
fi

# 2. No broad Photos permission, transport-security exception, or push background mode.
if grep -rnE 'NSPhotoLibraryUsageDescription|NSAppTransportSecurity|remote-notification' "$app_root/Resources" "$mac_root/Resources"; then
  print -u2 "forbidden plist capability found"
  exit 1
fi

# 3. No prototype HTML or custom fonts inside the app target.
if find "$app_root" "$mac_root" \( -name '*.html' -o -name '*.woff' -o -name '*.woff2' -o -name '*.ttf' -o -name '*.otf' \) -print | grep -q .; then
  print -u2 "prototype or custom font found in app target"
  exit 1
fi

# 4. No entitlements file, no package dependencies, no cloud or push entitlement in the project.
test ! -f "$app_root/Slate.entitlements"
if grep -qE 'XCRemoteSwiftPackageReference|XCLocalSwiftPackageReference|CODE_SIGN_ENTITLEMENTS' Slate.xcodeproj/project.pbxproj; then
  print -u2 "package dependency or entitlements setting found in project"
  exit 1
fi

# 5. The Mac app is sandboxed, may read only files the user picks, and holds no network entitlement.
if grep -qE 'ENABLE_(OUTGOING|INCOMING)_NETWORK_CONNECTIONS = YES|ENABLE_USER_SELECTED_FILES = readwrite' Slate.xcodeproj/project.pbxproj; then
  print -u2 "network or read-write file entitlement found in project"
  exit 1
fi
if [[ $(grep -c 'ENABLE_APP_SANDBOX = YES' Slate.xcodeproj/project.pbxproj) -lt 2 ]]; then
  print -u2 "Mac app sandbox is not enabled for every configuration"
  exit 1
fi

# 6. Property lists parse.
plutil -lint "$app_root/Resources/Info.plist" "$app_root/Resources/PrivacyInfo.xcprivacy" "$mac_root/Resources/Info.plist"

print "Slate release constraints passed"
