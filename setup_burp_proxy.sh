#!/bin/bash
#
# Burp Suite Android Proxy & Certificate Setup Script
# Automates proxy configuration and CA certificate installation
#
# Usage: ./setup_burp_proxy.sh [options]
#   -c, --cert PATH     Path to Burp certificate (default: ~/tools/burp.cer)
#   -p, --port PORT     Burp proxy port (default: 8080)
#   -i, --ip IP         Host IP address (auto-detected if not specified)
#   -r, --remove        Remove proxy and certificate
#   -h, --help          Show this help message
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BURP_CERT="${HOME}/tools/burp.cer"
BURP_PORT="8080"
HOST_IP=""
REMOVE_MODE=false

# Temp directory for certificate processing
TEMP_DIR="/tmp/burp_setup_$$"

#######################################
# Print colored message
#######################################
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#######################################
# Show help message
#######################################
show_help() {
    echo "Burp Suite Android Proxy & Certificate Setup Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -c, --cert PATH     Path to Burp certificate (default: ~/tools/burp.cer)"
    echo "  -p, --port PORT     Burp proxy port (default: 8080)"
    echo "  -i, --ip IP         Host IP address (auto-detected if not specified)"
    echo "  -r, --remove        Remove proxy and certificate"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Use defaults, auto-detect IP"
    echo "  $0 -c /path/to/burp.cer      # Specify certificate path"
    echo "  $0 -p 8081 -i 192.168.1.100  # Custom port and IP"
    echo "  $0 --remove                  # Remove proxy settings and certificate"
    exit 0
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--cert)
                BURP_CERT="$2"
                shift 2
                ;;
            -p|--port)
                BURP_PORT="$2"
                shift 2
                ;;
            -i|--ip)
                HOST_IP="$2"
                shift 2
                ;;
            -r|--remove)
                REMOVE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

#######################################
# Check prerequisites
#######################################
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check if ADB is installed
    if ! command -v adb &> /dev/null; then
        print_error "ADB is not installed or not in PATH"
        exit 1
    fi

    # Check if OpenSSL is installed
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is not installed or not in PATH"
        exit 1
    fi

    # Check if device is connected
    DEVICE_COUNT=$(adb devices | grep -v "List" | grep -c "device$" || true)
    if [[ $DEVICE_COUNT -eq 0 ]]; then
        print_error "No Android device connected"
        print_info "Connect a device and ensure USB debugging is enabled"
        exit 1
    elif [[ $DEVICE_COUNT -gt 1 ]]; then
        print_warning "Multiple devices connected. Using first device."
    fi

    print_success "Prerequisites check passed"
}

#######################################
# Detect host IP address
#######################################
detect_host_ip() {
    if [[ -z "$HOST_IP" ]]; then
        print_info "Auto-detecting host IP address..."
        
        # Try different methods to get IP
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS
            HOST_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
        else
            # Linux
            HOST_IP=$(hostname -I | awk '{print $1}')
        fi

        if [[ -z "$HOST_IP" ]]; then
            print_error "Could not detect host IP address. Please specify with -i option."
            exit 1
        fi
    fi

    print_success "Host IP: $HOST_IP"
}

#######################################
# Check if device is rooted
#######################################
check_root() {
    print_info "Checking device root status..."
    
    ROOT_USER=$(adb shell whoami 2>/dev/null | tr -d '\r\n')
    if [[ "$ROOT_USER" != "root" ]]; then
        print_warning "Device shell is not running as root"
        print_info "Attempting to get root access..."
        
        # Try 'adb root'
        adb root &>/dev/null || true
        sleep 2
        
        ROOT_USER=$(adb shell whoami 2>/dev/null | tr -d '\r\n')
        if [[ "$ROOT_USER" != "root" ]]; then
            # Try 'su' command
            SU_TEST=$(adb shell "su -c 'whoami'" 2>/dev/null | tr -d '\r\n')
            if [[ "$SU_TEST" == "root" ]]; then
                print_success "Root access available via 'su'"
                USE_SU=true
            else
                print_error "Device is not rooted or root access denied"
                print_info "Certificate installation requires root access"
                exit 1
            fi
        else
            print_success "Root access confirmed"
            USE_SU=false
        fi
    else
        print_success "Root access confirmed"
        USE_SU=false
    fi
}

#######################################
# Execute shell command (with su if needed)
#######################################
adb_root_cmd() {
    if [[ "$USE_SU" == "true" ]]; then
        adb shell "su -c '$1'" 2>/dev/null
    else
        adb shell "$1" 2>/dev/null
    fi
}

#######################################
# Configure proxy settings
#######################################
configure_proxy() {
    print_info "Configuring proxy: ${HOST_IP}:${BURP_PORT}..."
    
    adb shell "settings put global http_proxy ${HOST_IP}:${BURP_PORT}" 2>/dev/null
    
    # Verify
    CURRENT_PROXY=$(adb shell "settings get global http_proxy" 2>/dev/null | tr -d '\r\n')
    if [[ "$CURRENT_PROXY" == "${HOST_IP}:${BURP_PORT}" ]]; then
        print_success "Proxy configured: ${CURRENT_PROXY}"
    else
        print_error "Failed to configure proxy"
        exit 1
    fi
}

#######################################
# Remove proxy settings
#######################################
remove_proxy() {
    print_info "Removing proxy settings..."
    
    adb shell "settings put global http_proxy :0" 2>/dev/null
    
    CURRENT_PROXY=$(adb shell "settings get global http_proxy" 2>/dev/null | tr -d '\r\n')
    if [[ "$CURRENT_PROXY" == ":0" ]] || [[ "$CURRENT_PROXY" == "null" ]] || [[ -z "$CURRENT_PROXY" ]]; then
        print_success "Proxy removed"
    else
        print_warning "Proxy may not have been fully removed: ${CURRENT_PROXY}"
    fi
}

#######################################
# Install Burp certificate
#######################################
install_certificate() {
    print_info "Installing Burp certificate..."
    
    # Check if certificate file exists
    if [[ ! -f "$BURP_CERT" ]]; then
        print_error "Certificate file not found: $BURP_CERT"
        exit 1
    fi

    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Convert certificate to PEM format and get hash
    print_info "Processing certificate..."
    
    # Try DER format first, then PEM
    if openssl x509 -inform DER -in "$BURP_CERT" -out "$TEMP_DIR/burp.pem" 2>/dev/null; then
        print_info "Converted from DER format"
    elif openssl x509 -inform PEM -in "$BURP_CERT" -out "$TEMP_DIR/burp.pem" 2>/dev/null; then
        print_info "Certificate is in PEM format"
    else
        print_error "Could not process certificate file"
        cleanup
        exit 1
    fi

    # Get certificate hash
    CERT_HASH=$(openssl x509 -inform PEM -subject_hash_old -in "$TEMP_DIR/burp.pem" -noout 2>/dev/null)
    if [[ -z "$CERT_HASH" ]]; then
        print_error "Could not get certificate hash"
        cleanup
        exit 1
    fi
    
    CERT_FILE="${CERT_HASH}.0"
    print_info "Certificate hash: ${CERT_HASH}"

    # Create properly formatted certificate file
    cp "$TEMP_DIR/burp.pem" "$TEMP_DIR/${CERT_FILE}"

    # Check if certificate already exists
    EXISTING=$(adb_root_cmd "ls /system/etc/security/cacerts/${CERT_FILE} 2>/dev/null" | tr -d '\r\n')
    if [[ -n "$EXISTING" ]] && [[ "$EXISTING" != *"No such file"* ]]; then
        print_warning "Certificate already installed. Replacing..."
    fi

    # Push certificate to device
    print_info "Pushing certificate to device..."
    adb push "$TEMP_DIR/${CERT_FILE}" /sdcard/ &>/dev/null

    # Remount system as read-write
    print_info "Remounting system partition..."
    adb_root_cmd "mount -o rw,remount /" &>/dev/null || \
    adb_root_cmd "mount -o rw,remount /system" &>/dev/null || true

    # Copy certificate to CA store
    print_info "Installing certificate to system CA store..."
    adb_root_cmd "cp /sdcard/${CERT_FILE} /system/etc/security/cacerts/"
    adb_root_cmd "chmod 644 /system/etc/security/cacerts/${CERT_FILE}"
    adb_root_cmd "chown root:root /system/etc/security/cacerts/${CERT_FILE}"

    # Verify installation
    INSTALLED=$(adb_root_cmd "ls -la /system/etc/security/cacerts/${CERT_FILE}" | tr -d '\r\n')
    if [[ -n "$INSTALLED" ]] && [[ "$INSTALLED" != *"No such file"* ]]; then
        print_success "Certificate installed: /system/etc/security/cacerts/${CERT_FILE}"
    else
        print_error "Failed to install certificate"
        cleanup
        exit 1
    fi

    # Remount system as read-only
    print_info "Remounting system as read-only..."
    adb_root_cmd "mount -o ro,remount /" &>/dev/null || \
    adb_root_cmd "mount -o ro,remount /system" &>/dev/null || true

    # Cleanup device
    adb shell "rm -f /sdcard/${CERT_FILE}" &>/dev/null || true
    
    # Store certificate hash for potential removal
    echo "$CERT_HASH" > "$HOME/.burp_cert_hash" 2>/dev/null || true
}

#######################################
# Remove Burp certificate
#######################################
remove_certificate() {
    print_info "Removing Burp certificate..."
    
    # Try to get stored hash or calculate from cert
    if [[ -f "$HOME/.burp_cert_hash" ]]; then
        CERT_HASH=$(cat "$HOME/.burp_cert_hash")
    elif [[ -f "$BURP_CERT" ]]; then
        # Try to calculate hash from certificate
        TEMP_PEM="/tmp/burp_temp_$$.pem"
        if openssl x509 -inform DER -in "$BURP_CERT" -out "$TEMP_PEM" 2>/dev/null || \
           openssl x509 -inform PEM -in "$BURP_CERT" -out "$TEMP_PEM" 2>/dev/null; then
            CERT_HASH=$(openssl x509 -inform PEM -subject_hash_old -in "$TEMP_PEM" -noout 2>/dev/null)
            rm -f "$TEMP_PEM"
        fi
    fi

    if [[ -z "$CERT_HASH" ]]; then
        # Default PortSwigger hash
        CERT_HASH="9a5ba575"
        print_warning "Could not determine certificate hash, using default: ${CERT_HASH}"
    fi

    CERT_FILE="${CERT_HASH}.0"
    
    # Check if certificate exists
    EXISTING=$(adb_root_cmd "ls /system/etc/security/cacerts/${CERT_FILE} 2>/dev/null" | tr -d '\r\n')
    if [[ -z "$EXISTING" ]] || [[ "$EXISTING" == *"No such file"* ]]; then
        print_warning "Certificate not found on device"
        return 0
    fi

    # Remount system as read-write
    adb_root_cmd "mount -o rw,remount /" &>/dev/null || \
    adb_root_cmd "mount -o rw,remount /system" &>/dev/null || true

    # Remove certificate
    adb_root_cmd "rm -f /system/etc/security/cacerts/${CERT_FILE}"

    # Remount system as read-only
    adb_root_cmd "mount -o ro,remount /" &>/dev/null || \
    adb_root_cmd "mount -o ro,remount /system" &>/dev/null || true

    # Verify removal
    EXISTING=$(adb_root_cmd "ls /system/etc/security/cacerts/${CERT_FILE} 2>/dev/null" | tr -d '\r\n')
    if [[ -z "$EXISTING" ]] || [[ "$EXISTING" == *"No such file"* ]]; then
        print_success "Certificate removed"
        rm -f "$HOME/.burp_cert_hash" 2>/dev/null || true
    else
        print_error "Failed to remove certificate"
    fi
}

#######################################
# Cleanup temp files
#######################################
cleanup() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

#######################################
# Show final status
#######################################
show_status() {
    echo ""
    echo "=========================================="
    echo "         CONFIGURATION SUMMARY"
    echo "=========================================="
    
    CURRENT_PROXY=$(adb shell "settings get global http_proxy" 2>/dev/null | tr -d '\r\n')
    echo -e "Proxy:       ${GREEN}${CURRENT_PROXY}${NC}"
    
    if [[ -f "$HOME/.burp_cert_hash" ]]; then
        CERT_HASH=$(cat "$HOME/.burp_cert_hash")
        CERT_STATUS=$(adb_root_cmd "ls /system/etc/security/cacerts/${CERT_HASH}.0 2>/dev/null" | tr -d '\r\n')
        if [[ -n "$CERT_STATUS" ]] && [[ "$CERT_STATUS" != *"No such file"* ]]; then
            echo -e "Certificate: ${GREEN}Installed (${CERT_HASH}.0)${NC}"
        else
            echo -e "Certificate: ${YELLOW}Not installed${NC}"
        fi
    else
        echo -e "Certificate: ${YELLOW}Status unknown${NC}"
    fi
    
    echo "=========================================="
    echo ""
    
    if [[ "$REMOVE_MODE" != "true" ]]; then
        echo "Next steps:"
        echo "  1. Ensure Burp Suite is running and listening on ${HOST_IP}:${BURP_PORT}"
        echo "  2. In Burp: Proxy > Options > Bind to: All interfaces"
        echo "  3. Browse HTTPS sites on the device to test interception"
        echo ""
        echo "To remove configuration later:"
        echo "  $0 --remove"
    fi
}

#######################################
# Main function
#######################################
main() {
    echo ""
    echo "=========================================="
    echo "  Burp Suite Android Setup Script"
    echo "=========================================="
    echo ""
    
    parse_args "$@"
    check_prerequisites
    
    if [[ "$REMOVE_MODE" == "true" ]]; then
        print_info "Running in REMOVAL mode..."
        check_root
        remove_proxy
        remove_certificate
    else
        detect_host_ip
        check_root
        configure_proxy
        install_certificate
    fi
    
    cleanup
    show_status
    
    print_success "Done!"
}

# Run main function
main "$@"
