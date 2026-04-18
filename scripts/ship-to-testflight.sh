#!/usr/bin/env bash
# Ship a new TestFlight build end-to-end:
#   - bump CURRENT_PROJECT_VERSION in project.yml
#   - xcodegen generate
#   - archive (Release, automatic signing)
#   - export for App Store Connect distribution
#   - upload via altool
#   - poll until processing completes
#   - set "What to Test" release notes via App Store Connect API
#
# Usage:
#   scripts/ship-to-testflight.sh "release notes text (supports \n for newlines)"
#   scripts/ship-to-testflight.sh --marketing 1.2 "release notes for the 1.2 train"
#
# Credentials come from scripts/asc-config.env (gitignored).
# Copy scripts/asc-config.env.example to scripts/asc-config.env and fill in values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$SCRIPT_DIR/asc-config.env"

die() { echo "error: $*" >&2; exit 1; }
info() { echo "▸ $*"; }

[[ -f "$CONFIG" ]] || die "$CONFIG not found. Copy asc-config.env.example and fill in values."
# shellcheck disable=SC1090
source "$CONFIG"

: "${ASC_KEY_ID:?ASC_KEY_ID must be set in asc-config.env}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID must be set in asc-config.env}"
: "${ASC_KEY_PATH:?ASC_KEY_PATH must be set in asc-config.env}"
: "${ASC_TEAM_ID:?ASC_TEAM_ID must be set in asc-config.env}"
: "${ASC_APP_ID:?ASC_APP_ID must be set in asc-config.env}"
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
[[ -f "$ASC_KEY_PATH" ]] || die "ASC_KEY_PATH does not exist: $ASC_KEY_PATH"

cd "$PROJECT_ROOT"

# Default scheme/project derived from project.yml if not overridden
SCHEME="${ASC_SCHEME:-$(awk -F': ' '/^name:/ {print $2; exit}' project.yml)}"
PROJECT="${ASC_PROJECT:-${SCHEME}.xcodeproj}"
[[ -n "$SCHEME" ]] || die "could not determine scheme — set ASC_SCHEME in asc-config.env"
[[ -d "$PROJECT" ]] || die "project not found: $PROJECT (regenerate with xcodegen?)"

# Parse args
NEW_MARKETING=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --marketing)
            NEW_MARKETING="$2"; shift 2;;
        -h|--help)
            sed -n '2,20p' "$0"; exit 0;;
        -*)
            die "unknown flag: $1";;
        *)
            WHATS_NEW="$1"; shift;;
    esac
done
[[ -n "${WHATS_NEW:-}" ]] || die "missing release notes. usage: $0 \"notes\""

# ---------- bump version numbers ----------
CURRENT_BUILD=$(awk -F'"' '/CURRENT_PROJECT_VERSION:/ {print $2; exit}' project.yml)
NEXT_BUILD=$((CURRENT_BUILD + 1))
info "build: $CURRENT_BUILD → $NEXT_BUILD"
/usr/bin/sed -i '' "s/CURRENT_PROJECT_VERSION: \"$CURRENT_BUILD\"/CURRENT_PROJECT_VERSION: \"$NEXT_BUILD\"/" project.yml

if [[ -n "$NEW_MARKETING" ]]; then
    OLD_MARKETING=$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' project.yml)
    info "marketing: $OLD_MARKETING → $NEW_MARKETING"
    /usr/bin/sed -i '' "s/MARKETING_VERSION: \"$OLD_MARKETING\"/MARKETING_VERSION: \"$NEW_MARKETING\"/" project.yml
fi
MARKETING=$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' project.yml)

info "regenerating Xcode project"
xcodegen generate >/dev/null

# ---------- archive ----------
ARCHIVE=/tmp/${SCHEME}-ship.xcarchive
EXPORT_DIR=/tmp/${SCHEME}-ship-export
rm -rf "$ARCHIVE" "$EXPORT_DIR"

info "archiving ${MARKETING} (${NEXT_BUILD})"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    archive >/tmp/ship-archive.log 2>&1 \
    || { tail -40 /tmp/ship-archive.log; die "archive failed — see /tmp/ship-archive.log"; }

# ---------- export ----------
EXPORT_OPTS=/tmp/ship-ExportOptions.plist
cat > "$EXPORT_OPTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>$ASC_TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
    <key>uploadSymbols</key><true/>
    <key>destination</key><string>export</string>
</dict>
</plist>
EOF

info "exporting"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" >/tmp/ship-export.log 2>&1 \
    || { tail -40 /tmp/ship-export.log; die "export failed — see /tmp/ship-export.log"; }

IPA=$(ls "$EXPORT_DIR"/*.ipa | head -1)
[[ -f "$IPA" ]] || die "no .ipa produced in $EXPORT_DIR"

# ---------- upload ----------
info "uploading $(basename "$IPA")"
xcrun altool --upload-app \
    -f "$IPA" \
    -t ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID" \
    --output-format json >/tmp/ship-upload.log 2>&1 \
    || { cat /tmp/ship-upload.log; die "upload failed"; }

# ---------- poll & set release notes ----------
info "waiting for processing + setting release notes"
python3 "$SCRIPT_DIR/asc_set_whats_new.py" \
    --app-id "$ASC_APP_ID" \
    --version "$MARKETING" \
    --build "$NEXT_BUILD" \
    --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" \
    --key-path "$ASC_KEY_PATH" \
    --whats-new "$WHATS_NEW"

info "✓ shipped ${MARKETING} (${NEXT_BUILD})"
