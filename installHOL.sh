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

INSTALL_DIR="$SCRIPT_DIR/Hex"

mkdir -p "$INSTALL_DIR"

DOWNLOAD_PATH="$INSTALL_DIR/$ARCHIVE"

if [[ -d "$INSTALL_DIR" ]]; then
    find "$INSTALL_DIR" \
        -mindepth 1 \
        ! -name "$PACKAGE_LINK" \
        -exec rm -rf {} +
fi

echo "Downloading NW.js..."
curl -L "$URL" -o "$DOWNLOAD_PATH"

echo "Extracting..."
tar -xzf "$DOWNLOAD_PATH" \
    --strip-components=1 \
    -C "$INSTALL_DIR"

rm "$DOWNLOAD_PATH"

LINK="$INSTALL_DIR/$PACKAGE_LINK"

if [[ -L "$LINK" || -e "$LINK" ]]; then
    if [[ "$FORCE" == "true" ]]; then
        rm -rf "$LINK"
    else
        echo "$PACKAGE_LINK already exists."
        exit 1
    fi
fi

echo "Creating package symlink..."


resolve_package_target
validate_package_target

ln -s "$LINK_TARGET" "$LINK"

DESKTOP_FILE="$HOME/.local/share/applications/$DESKTOP_FILENAME"

mkdir -p "$HOME/.local/share/applications"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=$APP_NAME
Comment=$APP_COMMENT
Exec=$INSTALL_DIR/$EXECUTABLE $LINK
Icon=$LINK_TARGET/$ICON_PATH
Terminal=false
Type=Application
Categories=Game;
EOF

chmod +x "$DESKTOP_FILE"

echo
echo "Done!"
echo
echo "Desktop entry:"
echo "  $DESKTOP_FILE"




resolve_package_target() {
    if [[ "$(basename "$PACKAGE_SOURCE")" == "package.nw" ]]; then
        LINK_TARGET="$PACKAGE_SOURCE"
    elif [[ -e "$PACKAGE_SOURCE/package.nw" ]]; then
        LINK_TARGET="$PACKAGE_SOURCE/package.nw"
    else
        LINK_TARGET="$PACKAGE_SOURCE"
    fi
}

validate_package_target() {
    while [[ ! -e "$LINK_TARGET" ]]; do
        echo
        echo "package.nw was not found:"
        echo "  $LINK_TARGET"
        echo

        read -erp "Please enter the full path to the package.nw folder: " LINK_TARGET
    done
}