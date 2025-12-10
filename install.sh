#!/bin/sh
# Flipside CLI Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/FlipsideCrypto/flipside-tools/main/install.sh | sh
# Or with specific version: FLIPSIDE_VERSION=1.0.0 curl -fsSL ... | sh

set -e

# Configuration
REPO="FlipsideCrypto/flipside-tools"
BINARY_NAME="flipside"
GITHUB_API="https://api.github.com/repos/${REPO}/releases/latest"
GITHUB_DOWNLOAD="https://github.com/${REPO}/releases/download"

# Colors (only if terminal supports them)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

info() {
    printf "${BLUE}==>${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}==>${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}Warning:${NC} %s\n" "$1"
}

error() {
    printf "${RED}Error:${NC} %s\n" "$1" >&2
    exit 1
}

# Detect operating system
detect_os() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$OS" in
        darwin)
            echo "darwin"
            ;;
        linux)
            echo "linux"
            ;;
        mingw*|msys*|cygwin*)
            error "Windows is not supported by this installer. Please download the binary manually from GitHub releases."
            ;;
        *)
            error "Unsupported operating system: $OS"
            ;;
    esac
}

# Detect architecture
detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            error "Unsupported architecture: $ARCH"
            ;;
    esac
}

# Check for required commands
check_dependencies() {
    for cmd in curl tar; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "Required command not found: $cmd"
        fi
    done
}

# Get the latest version from GitHub API
get_latest_version() {
    info "Fetching latest version..."

    LATEST=$(curl -fsSL "$GITHUB_API" 2>/dev/null | grep '"tag_name"' | head -1 | sed -E 's/.*"v([^"]+)".*/\1/')

    if [ -z "$LATEST" ]; then
        error "Failed to fetch latest version from GitHub. Please check your internet connection or try again later."
    fi

    echo "$LATEST"
}

# Download and verify checksum
download_and_verify() {
    VERSION="$1"
    OS="$2"
    ARCH="$3"
    TMPDIR="$4"

    ARCHIVE_NAME="${BINARY_NAME}_${VERSION}_${OS}_${ARCH}.tar.gz"
    DOWNLOAD_URL="${GITHUB_DOWNLOAD}/v${VERSION}/${ARCHIVE_NAME}"
    CHECKSUM_URL="${GITHUB_DOWNLOAD}/v${VERSION}/checksums.txt"

    info "Downloading ${BINARY_NAME} v${VERSION} for ${OS}/${ARCH}..."

    # Download the archive
    if ! curl -fsSL -o "${TMPDIR}/${ARCHIVE_NAME}" "$DOWNLOAD_URL"; then
        error "Failed to download ${ARCHIVE_NAME}. URL: ${DOWNLOAD_URL}"
    fi

    # Download checksums
    info "Verifying checksum..."
    if ! curl -fsSL -o "${TMPDIR}/checksums.txt" "$CHECKSUM_URL"; then
        warn "Could not download checksums file. Skipping verification."
        return 0
    fi

    # Verify checksum
    EXPECTED_CHECKSUM=$(grep "${ARCHIVE_NAME}" "${TMPDIR}/checksums.txt" | awk '{print $1}')
    if [ -z "$EXPECTED_CHECKSUM" ]; then
        warn "Checksum not found for ${ARCHIVE_NAME}. Skipping verification."
        return 0
    fi

    # Calculate checksum (macOS uses shasum, Linux uses sha256sum)
    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL_CHECKSUM=$(sha256sum "${TMPDIR}/${ARCHIVE_NAME}" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        ACTUAL_CHECKSUM=$(shasum -a 256 "${TMPDIR}/${ARCHIVE_NAME}" | awk '{print $1}')
    else
        warn "Neither sha256sum nor shasum found. Skipping checksum verification."
        return 0
    fi

    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        error "Checksum verification failed!\nExpected: ${EXPECTED_CHECKSUM}\nActual:   ${ACTUAL_CHECKSUM}\nThe download may be corrupted. Please try again."
    fi

    success "Checksum verified"
}

# Extract the binary
extract_binary() {
    TMPDIR="$1"
    VERSION="$2"
    OS="$3"
    ARCH="$4"

    ARCHIVE_NAME="${BINARY_NAME}_${VERSION}_${OS}_${ARCH}.tar.gz"

    info "Extracting..."
    tar -xzf "${TMPDIR}/${ARCHIVE_NAME}" -C "${TMPDIR}"

    if [ ! -f "${TMPDIR}/${BINARY_NAME}" ]; then
        error "Binary not found after extraction"
    fi

    chmod +x "${TMPDIR}/${BINARY_NAME}"
}

# Determine installation directory
determine_install_dir() {
    # Check if user specified a directory
    if [ -n "$INSTALL_DIR" ]; then
        echo "$INSTALL_DIR"
        return
    fi

    # Try /usr/local/bin first (requires root usually)
    if [ -w "/usr/local/bin" ]; then
        echo "/usr/local/bin"
        return
    fi

    # Check if running as root
    if [ "$(id -u)" = "0" ]; then
        echo "/usr/local/bin"
        return
    fi

    # Fall back to ~/.local/bin
    LOCAL_BIN="${HOME}/.local/bin"
    if [ ! -d "$LOCAL_BIN" ]; then
        mkdir -p "$LOCAL_BIN"
    fi
    echo "$LOCAL_BIN"
}

# Install the binary
install_binary() {
    TMPDIR="$1"
    INSTALL_DIR="$2"

    TARGET="${INSTALL_DIR}/${BINARY_NAME}"

    # Check if directory exists
    if [ ! -d "$INSTALL_DIR" ]; then
        if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
            error "Cannot create directory: ${INSTALL_DIR}\nTry running with sudo or set INSTALL_DIR to a writable location."
        fi
    fi

    # Check if we can write to the directory
    if [ ! -w "$INSTALL_DIR" ]; then
        error "Cannot write to ${INSTALL_DIR}\nTry running with sudo: curl -fsSL ... | sudo sh"
    fi

    # Move binary to target
    if ! mv "${TMPDIR}/${BINARY_NAME}" "$TARGET" 2>/dev/null; then
        error "Failed to install binary to ${TARGET}"
    fi

    success "Installed to ${TARGET}"
}

# Check if install directory is in PATH
check_path() {
    INSTALL_DIR="$1"

    case ":$PATH:" in
        *":${INSTALL_DIR}:"*)
            # Already in PATH
            return 0
            ;;
    esac

    # Not in PATH, show instructions
    echo ""
    warn "${INSTALL_DIR} is not in your PATH"
    echo ""
    echo "Add it to your shell configuration:"
    echo ""

    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        bash)
            echo "  echo 'export PATH=\"\$PATH:${INSTALL_DIR}\"' >> ~/.bashrc"
            echo "  source ~/.bashrc"
            ;;
        zsh)
            echo "  echo 'export PATH=\"\$PATH:${INSTALL_DIR}\"' >> ~/.zshrc"
            echo "  source ~/.zshrc"
            ;;
        fish)
            echo "  fish_add_path ${INSTALL_DIR}"
            ;;
        *)
            echo "  export PATH=\"\$PATH:${INSTALL_DIR}\""
            ;;
    esac
    echo ""
}

# Verify installation
verify_installation() {
    INSTALL_DIR="$1"
    TARGET="${INSTALL_DIR}/${BINARY_NAME}"

    if [ ! -x "$TARGET" ]; then
        error "Installation verification failed: ${TARGET} is not executable"
    fi

    # Try to get version
    INSTALLED_VERSION=$("$TARGET" --version 2>/dev/null | head -1) || true
    if [ -n "$INSTALLED_VERSION" ]; then
        success "Verified: ${INSTALLED_VERSION}"
    fi
}

# Cleanup
cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}

# Main installation function
main() {
    echo ""
    echo "Flipside CLI Installer"
    echo "======================"
    echo ""

    # Check dependencies
    check_dependencies

    # Detect platform
    OS=$(detect_os)
    ARCH=$(detect_arch)
    info "Detected platform: ${OS}/${ARCH}"

    # Get version (from env or latest)
    if [ -n "$FLIPSIDE_VERSION" ]; then
        VERSION="$FLIPSIDE_VERSION"
        info "Using specified version: v${VERSION}"
    else
        VERSION=$(get_latest_version)
        info "Latest version: v${VERSION}"
    fi

    # Create temp directory
    TMPDIR=$(mktemp -d)
    trap cleanup EXIT

    # Download and verify
    download_and_verify "$VERSION" "$OS" "$ARCH" "$TMPDIR"

    # Extract
    extract_binary "$TMPDIR" "$VERSION" "$OS" "$ARCH"

    # Determine install location
    INSTALL_DIR=$(determine_install_dir)
    info "Installing to: ${INSTALL_DIR}"

    # Install
    install_binary "$TMPDIR" "$INSTALL_DIR"

    # Check PATH
    check_path "$INSTALL_DIR"

    # Verify
    verify_installation "$INSTALL_DIR"

    echo ""
    success "Installation complete!"
    echo ""
    echo "Get started:"
    echo "  ${BINARY_NAME} config init    # Configure your API key"
    echo "  ${BINARY_NAME} --help         # Show available commands"
    echo ""
}

# Run main
main
