#!/usr/bin/env bash

pause() {
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    echo
}

extract_nwjs() {
	echo "Downloading NW.js..."
	curl -L "$URL" -o "$DOWNLOAD_PATH"

	echo "Extracting..."
	tar -xzf "$DOWNLOAD_PATH" \
		--strip-components=1 \
		-C "$INSTALL_DIR"

	rm "$DOWNLOAD_PATH"
}

resolve_package_target() {
    while true; do
        if [[ "$(basename "$PACKAGE_SOURCE")" == "package.nw" ]]; then
            LINK_TARGET="$PACKAGE_SOURCE"
            return
        fi

        if [[ -d "$PACKAGE_SOURCE/package.nw" ]]; then
            LINK_TARGET="$PACKAGE_SOURCE/package.nw"
            return
        fi

        echo
        echo "No package.nw folder was found."
        echo "You can select either:"
        echo "  • the Hex project folder (containing package.nw)"
        echo "  • the package.nw folder itself"
        echo

        read -erp "Please enter the correct path: " PACKAGE_SOURCE
        check_package_source
    done
}

check_package_source() {
    while [[ ! -e "$PACKAGE_SOURCE" ]]; do
        echo
        echo "The specified path does not exist:"
        echo "  $PACKAGE_SOURCE"
        echo

        read -erp "Please enter the path to your Hex project or package.nw folder: " PACKAGE_SOURCE
    done
}

create_desktop_file() {
    DESKTOP_FILE="$HOME/.local/share/applications/$DESKTOP_FILENAME"

    if [[ -f "$DESKTOP_FILE" ]]; then
        if grep -q "^X-Hex-On-Linux-Installer=true$" "$DESKTOP_FILE"; then
            echo "Removing previous desktop entry..."
            rm -f "$DESKTOP_FILE"
        else
            echo "A desktop entry named '$DESKTOP_FILENAME' already exists but"
            echo "it was not created by this installer."
            echo "Please remove or rename it manually."
            exit 1
        fi
    fi

    mkdir -p "$HOME/.local/share/applications"

	cat > "$DESKTOP_FILE" <<-EOF
	[Desktop Entry]
	Name=$APP_NAME
	Comment=$APP_COMMENT
	Exec=$INSTALL_DIR/$EXECUTABLE $LINK
	Icon=$LINK_TARGET/$ICON_PATH
	Terminal=false
	Type=Application
	Categories=Game;
	X-Hex-On-Linux-Installer=true
	EOF

    chmod +x "$DESKTOP_FILE"

    echo
    echo "Done!"
    echo
    echo "Desktop entry:"
    echo "  $DESKTOP_FILE"
}

installHexOnLinux() {
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
			-exec rm -rf {} +
	fi

	extract_nwjs

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

	check_package_source
	resolve_package_target

	ln -s "$LINK_TARGET" "$LINK"

	create_desktop_file
}

uninstallHexOnLinux() {
	echo Uninstalling Hex
	if [[ -d "$SCRIPT_DIR/Hex" ]]; then
		rm -rf -- "$SCRIPT_DIR/Hex"
	fi
}

menu() {
	clear
	echo "1) Install"
	echo "2) Uninstall"
	echo "3) Steam patch (Not yet implemented)"
	echo "c) Quit"

	read -rp "Enter your choice: " choice

	case "$choice" in
		1) installHexOnLinux ;;
		2) uninstallHexOnLinux ;;
		3) echo "Restarting..." ;;
		c) echo "Steam patch (Not yet implemented)!" ;;
		*) menu ;;
	esac
}

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

menu

trap pause EXIT