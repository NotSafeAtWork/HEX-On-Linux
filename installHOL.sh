#!/usr/bin/env bash

if [[ -z "${INSTALLER_TERMINAL:-}" && ! -t 1 ]]; then
    export INSTALLER_TERMINAL=1

    for term in x-terminal-emulator gnome-terminal konsole xfce4-terminal kitty alacritty xterm; do
        if command -v "${term%% *}" >/dev/null 2>&1; then
            exec "$term" -e bash "$0" "$@"
        fi
    done

    echo "No terminal emulator found."
    exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/config.conf"

if [[ ! -f "$CONFIG" ]]; then
    echo "Missing config.conf"
    exit 1
fi

source "$CONFIG"

if [[ "$BUILD" == "sdk" ]]; then
    FLAVOR="nwjs-sdk"
else
    FLAVOR="nwjs"
fi

ARCHIVE="${FLAVOR}-v${NWJS_VERSION}-${ARCH}.tar.gz"
URL="https://dl.nwjs.io/v${NWJS_VERSION}/${ARCHIVE}"

DOWNLOAD_PATH="$SCRIPT_DIR/$ARCHIVE"
EXTRACT_DIR="$SCRIPT_DIR/${FLAVOR}-v${NWJS_VERSION}-${ARCH}"

echo "Downloading NW.js..."
curl -L "$URL" -o "$DOWNLOAD_PATH"

echo "Extracting..."
tar -xzf "$DOWNLOAD_PATH" \
    --strip-components=1 \
    -C "$SCRIPT_DIR"

rm "$DOWNLOAD_PATH"

LINK="$SCRIPT_DIR/$PACKAGE_LINK"

if [[ -L "$LINK" || -e "$LINK" ]]; then
    if [[ "$FORCE" == "true" ]]; then
        rm -rf "$LINK"
    else
        echo "$PACKAGE_LINK already exists."
        exit 1
    fi
fi

echo "Creating package symlink..."
if [[ "$(basename "$PACKAGE_SOURCE")" == "package.nw" ]]; then
    LINK_TARGET="$PACKAGE_SOURCE"
else
    LINK_TARGET="$PACKAGE_SOURCE/package.nw"
    [[ -e "$LINK_TARGET" ]] || LINK_TARGET="$PACKAGE_SOURCE"
fi

ln -s "$LINK_TARGET" "$LINK"

ln -s "$PACKAGE_SOURCE" "$LINK"

DESKTOP_FILE="$HOME/.local/share/applications/$DESKTOP_FILENAME"

mkdir -p "$HOME/.local/share/applications"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$APP_NAME
Exec=$SCRIPT_DIR/$EXECUTABLE $LINK
Icon=$PACKAGE_SOURCE/$ICON_PATH
Terminal=false
Categories=Utility;
EOF

chmod +x "$DESKTOP_FILE"

echo
echo "Done!"
echo
echo "Desktop entry:"
echo "  $DESKTOP_FILE"
