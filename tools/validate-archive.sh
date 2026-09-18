#!/bin/bash
# validate-archive.sh — Check that the Watch app is properly embedded in an Xcode archive.
# Usage: ./tools/validate-archive.sh /path/to/WatchSpeaksNotifications.xcarchive
#
# Checks:
# 1. Archive exists and has expected structure
# 2. Watch app is embedded in the iOS app
# 3. Watch app Info.plist has required keys
# 4. Version numbers match between iOS and Watch
# 5. Code signing is consistent
# 6. No unexpected entitlements on Watch binary

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}!${NC} $1"; }

ERRORS=0

if [ -z "${1:-}" ]; then
    echo "Usage: $0 /path/to/WatchSpeaksNotifications.xcarchive"
    echo ""
    echo "Find your latest archive:"
    echo "  ls -td ~/Library/Developer/Xcode/Archives/*/*.xcarchive | head -5"
    exit 1
fi

ARCHIVE="$1"

echo "========================================"
echo "Watch Speaks Archive Validator"
echo "========================================"
echo "Archive: $ARCHIVE"
echo ""

# 1. Archive structure
echo "--- Archive Structure ---"
if [ -d "$ARCHIVE" ]; then
    pass "Archive exists"
else
    fail "Archive not found: $ARCHIVE"
    exit 1
fi

IOS_APP=$(find "$ARCHIVE/Products/Applications" -name "*.app" -maxdepth 1 -type d 2>/dev/null | head -1)
if [ -n "$IOS_APP" ]; then
    pass "iOS app found: $(basename "$IOS_APP")"
else
    fail "iOS app not found in archive"
    exit 1
fi

# 2. Watch app embedded
echo ""
echo "--- Watch App ---"
WATCH_DIR="$IOS_APP/Watch"
if [ -d "$WATCH_DIR" ]; then
    pass "Watch/ directory exists in iOS app"
else
    fail "Watch/ directory MISSING from iOS app"
    echo "  This means the Watch app was not embedded during archiving."
    echo "  Check: Embed Watch Content build phase in Xcode."
    exit 1
fi

WATCH_APP=$(find "$WATCH_DIR" -name "*.app" -maxdepth 1 -type d 2>/dev/null | head -1)
if [ -n "$WATCH_APP" ]; then
    pass "Watch app found: $(basename "$WATCH_APP")"
else
    fail "Watch .app bundle MISSING from Watch/ directory"
    exit 1
fi

# 3. Watch app Info.plist
echo ""
echo "--- Watch Info.plist ---"
WATCH_PLIST="$WATCH_APP/Info.plist"
if [ -f "$WATCH_PLIST" ]; then
    pass "Watch Info.plist exists"
else
    fail "Watch Info.plist MISSING"
    exit 1
fi

WK_APP=$(/usr/libexec/PlistBuddy -c "Print :WKApplication" "$WATCH_PLIST" 2>/dev/null || echo "MISSING")
if [ "$WK_APP" = "true" ]; then
    pass "WKApplication = true"
else
    fail "WKApplication = $WK_APP (expected true)"
fi

WK_COMPANION=$(/usr/libexec/PlistBuddy -c "Print :WKCompanionAppBundleIdentifier" "$WATCH_PLIST" 2>/dev/null || echo "MISSING")
IOS_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$IOS_APP/Info.plist" 2>/dev/null || echo "MISSING")
if [ "$WK_COMPANION" = "$IOS_BUNDLE_ID" ]; then
    pass "WKCompanionAppBundleIdentifier matches iOS bundle ID ($WK_COMPANION)"
else
    fail "WKCompanionAppBundleIdentifier mismatch: Watch=$WK_COMPANION, iOS=$IOS_BUNDLE_ID"
fi

# 4. Version matching
echo ""
echo "--- Version Numbers ---"
IOS_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$IOS_APP/Info.plist" 2>/dev/null || echo "?")
IOS_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$IOS_APP/Info.plist" 2>/dev/null || echo "?")
WATCH_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$WATCH_PLIST" 2>/dev/null || echo "?")
WATCH_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$WATCH_PLIST" 2>/dev/null || echo "?")

echo "  iPhone: $IOS_VER ($IOS_BUILD)"
echo "  Watch:  $WATCH_VER ($WATCH_BUILD)"

if [ "$IOS_VER" = "$WATCH_VER" ]; then
    pass "Marketing versions match"
else
    fail "Marketing version MISMATCH: iOS=$IOS_VER Watch=$WATCH_VER"
fi

if [ "$IOS_BUILD" = "$WATCH_BUILD" ]; then
    pass "Build numbers match"
else
    warn "Build numbers differ: iOS=$IOS_BUILD Watch=$WATCH_BUILD (may be OK)"
fi

# 5. Watch app bundle ID
WATCH_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$WATCH_PLIST" 2>/dev/null || echo "MISSING")
echo "  Watch bundle ID: $WATCH_BUNDLE_ID"
if [[ "$WATCH_BUNDLE_ID" == "$IOS_BUNDLE_ID."* ]]; then
    pass "Watch bundle ID is child of iOS bundle ID"
else
    warn "Watch bundle ID ($WATCH_BUNDLE_ID) is not a child of iOS ($IOS_BUNDLE_ID)"
fi

# 6. Code signing
echo ""
echo "--- Code Signing ---"
if codesign -v "$WATCH_APP" 2>/dev/null; then
    pass "Watch app code signature valid"
else
    fail "Watch app code signature INVALID"
fi

# 7. Entitlements
echo ""
echo "--- Watch Entitlements ---"
WATCH_EXEC="$WATCH_APP/$(basename "${WATCH_APP%.app}")"
if [ -f "$WATCH_EXEC" ]; then
    ENTS=$(codesign -d --entitlements - "$WATCH_APP" 2>/dev/null || echo "")
    if echo "$ENTS" | grep -q "time-sensitive"; then
        fail "Watch still has time-sensitive entitlement!"
    else
        pass "No time-sensitive entitlement on Watch"
    fi
    echo "  All Watch entitlements:"
    echo "$ENTS" | grep -v "^Executable" | head -30
else
    warn "Could not find Watch executable"
fi

# 8. Widget extension in Watch app
echo ""
echo "--- Widget Extension ---"
WIDGET_DIR="$WATCH_APP/PlugIns"
if [ -d "$WIDGET_DIR" ]; then
    WIDGET=$(find "$WIDGET_DIR" -name "*.appex" -maxdepth 1 -type d 2>/dev/null | head -1)
    if [ -n "$WIDGET" ]; then
        pass "Widget extension found: $(basename "$WIDGET")"
        WIDGET_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$WIDGET/Info.plist" 2>/dev/null || echo "?")
        WIDGET_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$WIDGET/Info.plist" 2>/dev/null || echo "?")
        echo "  Widget: $WIDGET_VER ($WIDGET_BUILD)"
    else
        warn "No widget extension found in PlugIns/"
    fi
else
    warn "No PlugIns/ directory in Watch app"
fi

# Summary
echo ""
echo "========================================"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}FAILED: $ERRORS error(s) found${NC}"
    echo "Fix the issues above before uploading to App Store Connect."
else
    echo -e "${GREEN}PASSED: Archive looks correct${NC}"
    echo "If the Watch app still fails to install from App Store,"
    echo "the issue is in Apple's server-side processing."
fi
echo "========================================"
exit $ERRORS
