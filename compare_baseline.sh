#!/bin/bash
# Android App - Baseline Comparison Script
# Created: 2026-01-18
# Updated: 2026-01-19
# Purpose: Detect changes in app data directory for security assessment
# Usage: ./compare_baseline.sh <package_name> [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_BASE_DIR="$SCRIPT_DIR"
ACTION="compare"

# Function to display usage
usage() {
    echo -e "${CYAN}Android App - Baseline Comparison Tool${NC}"
    echo ""
    echo "Usage: $0 <package_name> [options]"
    echo ""
    echo "Arguments:"
    echo "  package_name          Android package name (e.g., com.irobot.home)"
    echo ""
    echo "Options:"
    echo "  -o, --output DIR      Output directory (default: script directory)"
    echo "  -b, --baseline        Create new baseline (instead of comparing)"
    echo "  -c, --compare         Compare current state to baseline (default)"
    echo "  -l, --list            List available baselines"
    echo "  -v, --verbose         Verbose output"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 com.irobot.home -b              # Create baseline for iRobot app"
    echo "  $0 com.irobot.home -c              # Compare iRobot app to baseline"
    echo "  $0 com.whatsapp -o /tmp/assessment # Custom output directory"
    echo "  $0 -l                              # List all baselines"
    echo ""
    exit 1
}

# Function to check ADB connection
check_adb() {
    if ! command -v adb &> /dev/null; then
        echo -e "${RED}[!] ADB not found. Please install Android SDK Platform Tools.${NC}"
        exit 1
    fi
    
    if ! adb devices | grep -q "device$"; then
        echo -e "${RED}[!] No Android device connected or device not authorized.${NC}"
        echo -e "${YELLOW}    Run 'adb devices' to check connection status.${NC}"
        exit 1
    fi
}

# Function to check root access
check_root() {
    local root_check=$(adb shell "su -c 'echo root'" 2>/dev/null)
    if [ "$root_check" != "root" ]; then
        echo -e "${YELLOW}[!] Warning: Device may not have root access.${NC}"
        echo -e "${YELLOW}    Some files in /data/data/ may not be accessible.${NC}"
        return 1
    fi
    return 0
}

# Function to verify package exists
verify_package() {
    local pkg="$1"
    if ! adb shell pm list packages | grep -q "package:$pkg$"; then
        echo -e "${RED}[!] Package '$pkg' not found on device.${NC}"
        echo -e "${YELLOW}    Use 'adb shell pm list packages | grep <keyword>' to find packages.${NC}"
        exit 1
    fi
}

# Function to pull app data
pull_app_data() {
    local pkg="$1"
    local dest_dir="$2"
    
    echo -e "${BLUE}[*] Pulling app data for ${pkg}...${NC}"
    
    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    
    # Try with root first, fall back to non-root
    if check_root 2>/dev/null; then
        # Use root to pull data
        adb shell "su -c 'cp -r /data/data/$pkg /sdcard/temp_app_data'" 2>/dev/null
        adb pull /sdcard/temp_app_data "$dest_dir/" 2>/dev/null
        adb shell "rm -rf /sdcard/temp_app_data" 2>/dev/null
        
        # Rename the pulled directory
        if [ -d "$dest_dir/temp_app_data" ]; then
            mv "$dest_dir/temp_app_data" "$dest_dir/$pkg"
        fi
    else
        # Try direct pull (may work for debuggable apps)
        adb pull "/data/data/$pkg/" "$dest_dir/" 2>/dev/null || {
            echo -e "${RED}[!] Failed to pull app data. Root access may be required.${NC}"
            exit 1
        }
    fi
    
    echo -e "${GREEN}[+] App data pulled successfully.${NC}"
}

# Function to generate file hashes
generate_hashes() {
    local dir="$1"
    local output_file="$2"
    
    echo -e "${BLUE}[*] Generating file hashes...${NC}"
    
    cd "$dir"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses md5
        find . -type f -exec md5 {} \; > "$output_file" 2>/dev/null
    else
        # Linux uses md5sum
        find . -type f -exec md5sum {} \; > "$output_file" 2>/dev/null
    fi
    
    echo -e "${GREEN}[+] Generated $(wc -l < "$output_file" | tr -d ' ') file hashes.${NC}"
}

# Function to create baseline
create_baseline() {
    local pkg="$1"
    local output_dir="$2"
    
    local pkg_dir="$output_dir/${pkg}_assessment"
    local baseline_dir="$pkg_dir/app_data_baseline"
    local hashes_file="$pkg_dir/baseline_hashes.md5"
    local metadata_file="$pkg_dir/baseline_metadata.txt"
    
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}Creating Baseline for: ${pkg}${NC}"
    echo -e "${CYAN}Timestamp: $(date)${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    
    # Create directory structure
    mkdir -p "$pkg_dir"
    
    # Check for existing baseline
    if [ -d "$baseline_dir" ]; then
        echo -e "${YELLOW}[!] Existing baseline found.${NC}"
        read -p "    Overwrite? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*] Baseline creation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Pull app data
    pull_app_data "$pkg" "$baseline_dir"
    
    # Generate hashes
    generate_hashes "$baseline_dir" "$hashes_file"
    
    # Create metadata file
    cat > "$metadata_file" << EOF
Package: $pkg
Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Device: $(adb shell getprop ro.product.model | tr -d '\r')
Android Version: $(adb shell getprop ro.build.version.release | tr -d '\r')
App Version: $(adb shell dumpsys package $pkg | grep versionName | head -1 | awk -F'=' '{print $2}' | tr -d '\r')
Total Files: $(find "$baseline_dir" -type f | wc -l | tr -d ' ')
EOF
    
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}Baseline created successfully!${NC}"
    echo -e "${GREEN}Location: $pkg_dir${NC}"
    echo -e "${GREEN}==========================================${NC}"
}

# Function to compare to baseline
compare_to_baseline() {
    local pkg="$1"
    local output_dir="$2"
    
    local pkg_dir="$output_dir/${pkg}_assessment"
    local baseline_dir="$pkg_dir/app_data_baseline"
    local current_dir="$pkg_dir/app_data_current"
    local baseline_hashes="$pkg_dir/baseline_hashes.md5"
    local current_hashes="$pkg_dir/current_hashes.md5"
    local report_file="$pkg_dir/comparison_report_$(date +%Y%m%d_%H%M%S).txt"
    
    # Check if baseline exists
    if [ ! -d "$baseline_dir" ]; then
        echo -e "${RED}[!] No baseline found for '$pkg'.${NC}"
        echo -e "${YELLOW}    Run '$0 $pkg -b' to create a baseline first.${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}Comparing: ${pkg}${NC}"
    echo -e "${CYAN}Timestamp: $(date)${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    
    # Pull current app data
    pull_app_data "$pkg" "$current_dir"
    
    # Generate current hashes
    generate_hashes "$current_dir" "$current_hashes"
    
    # Start report
    {
        echo "=========================================="
        echo "Comparison Report: $pkg"
        echo "Timestamp: $(date)"
        echo "=========================================="
        echo ""
    } > "$report_file"
    
    # Compare file lists - NEW FILES
    echo -e "${YELLOW}=== NEW FILES ===${NC}"
    echo "=== NEW FILES ===" >> "$report_file"
    
    new_files=$(diff <(find "$baseline_dir" -type f | sed "s|$baseline_dir||" | sort) \
                     <(find "$current_dir" -type f | sed "s|$current_dir||" | sort) 2>/dev/null | grep "^>" | sed 's/^> //' || true)
    
    if [ -n "$new_files" ]; then
        echo -e "${GREEN}$new_files${NC}"
        echo "$new_files" >> "$report_file"
    else
        echo "(none)"
        echo "(none)" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    # Compare file lists - DELETED FILES
    echo ""
    echo -e "${YELLOW}=== DELETED FILES ===${NC}"
    echo "=== DELETED FILES ===" >> "$report_file"
    
    deleted_files=$(diff <(find "$baseline_dir" -type f | sed "s|$baseline_dir||" | sort) \
                         <(find "$current_dir" -type f | sed "s|$current_dir||" | sort) 2>/dev/null | grep "^<" | sed 's/^< //' || true)
    
    if [ -n "$deleted_files" ]; then
        echo -e "${RED}$deleted_files${NC}"
        echo "$deleted_files" >> "$report_file"
    else
        echo "(none)"
        echo "(none)" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    # Compare file hashes - MODIFIED FILES
    echo ""
    echo -e "${YELLOW}=== MODIFIED FILES ===${NC}"
    echo "=== MODIFIED FILES ===" >> "$report_file"
    
    modified_count=0
    while IFS= read -r line; do
        # Handle both md5 (macOS) and md5sum (Linux) formats
        if [[ "$OSTYPE" == "darwin"* ]]; then
            file=$(echo "$line" | awk -F'[()]' '{print $2}')
            baseline_hash=$(echo "$line" | awk '{print $NF}')
        else
            baseline_hash=$(echo "$line" | awk '{print $1}')
            file=$(echo "$line" | awk '{print $2}')
        fi
        
        current_file="$current_dir/${file#./}"
        if [ -f "$current_file" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                current_hash=$(md5 "$current_file" 2>/dev/null | awk '{print $NF}')
            else
                current_hash=$(md5sum "$current_file" 2>/dev/null | awk '{print $1}')
            fi
            
            if [ "$baseline_hash" != "$current_hash" ]; then
                ((modified_count++))
                echo -e "${BLUE}MODIFIED: $file${NC}"
                echo "  Baseline: $baseline_hash"
                echo "  Current:  $current_hash"
                {
                    echo "MODIFIED: $file"
                    echo "  Baseline: $baseline_hash"
                    echo "  Current:  $current_hash"
                } >> "$report_file"
            fi
        fi
    done < "$baseline_hashes"
    
    if [ $modified_count -eq 0 ]; then
        echo "(none)"
        echo "(none)" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    # Compare SharedPreferences
    echo ""
    echo -e "${YELLOW}=== SHARED PREFERENCES CHANGES ===${NC}"
    echo "=== SHARED PREFERENCES CHANGES ===" >> "$report_file"
    
    prefs_found=false
    # Find all shared_prefs directories
    for prefs_dir in $(find "$current_dir" -type d -name "shared_prefs" 2>/dev/null); do
        relative_path="${prefs_dir#$current_dir/}"
        baseline_prefs_dir="$baseline_dir/$relative_path"
        
        if [ -d "$baseline_prefs_dir" ]; then
            for pref in "$prefs_dir"/*.xml; do
                [ -f "$pref" ] || continue
                basename=$(basename "$pref")
                baseline_pref="$baseline_prefs_dir/$basename"
                
                if [ -f "$baseline_pref" ]; then
                    diff_output=$(diff "$baseline_pref" "$pref" 2>/dev/null || true)
                    if [ -n "$diff_output" ]; then
                        prefs_found=true
                        echo -e "${BLUE}--- $relative_path/$basename ---${NC}"
                        echo "$diff_output"
                        {
                            echo "--- $relative_path/$basename ---"
                            echo "$diff_output"
                        } >> "$report_file"
                        echo ""
                    fi
                else
                    prefs_found=true
                    echo -e "${GREEN}NEW PREF: $relative_path/$basename${NC}"
                    echo "NEW PREF: $relative_path/$basename" >> "$report_file"
                fi
            done
        fi
    done
    
    if [ "$prefs_found" = false ]; then
        echo "(no changes)"
        echo "(no changes)" >> "$report_file"
    fi
    
    # Compare databases
    echo ""
    echo -e "${YELLOW}=== DATABASE CHANGES ===${NC}"
    echo "=== DATABASE CHANGES ===" >> "$report_file"
    
    db_changes=false
    for db_dir in $(find "$current_dir" -type d -name "databases" 2>/dev/null); do
        relative_path="${db_dir#$current_dir/}"
        baseline_db_dir="$baseline_dir/$relative_path"
        
        for db in "$db_dir"/*.db "$db_dir"/*.sqlite "$db_dir"/*.sqlite3; do
            [ -f "$db" ] || continue
            basename=$(basename "$db")
            baseline_db="$baseline_db_dir/$basename"
            
            if [ -f "$baseline_db" ]; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    current_hash=$(md5 -q "$db" 2>/dev/null)
                    baseline_hash=$(md5 -q "$baseline_db" 2>/dev/null)
                else
                    current_hash=$(md5sum "$db" 2>/dev/null | awk '{print $1}')
                    baseline_hash=$(md5sum "$baseline_db" 2>/dev/null | awk '{print $1}')
                fi
                
                if [ "$current_hash" != "$baseline_hash" ]; then
                    db_changes=true
                    echo -e "${BLUE}MODIFIED: $relative_path/$basename${NC}"
                    echo "MODIFIED: $relative_path/$basename" >> "$report_file"
                fi
            else
                db_changes=true
                echo -e "${GREEN}NEW DB: $relative_path/$basename${NC}"
                echo "NEW DB: $relative_path/$basename" >> "$report_file"
            fi
        done
    done
    
    if [ "$db_changes" = false ]; then
        echo "(no changes)"
        echo "(no changes)" >> "$report_file"
    fi
    
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}Comparison complete!${NC}"
    echo -e "${CYAN}Report saved: $report_file${NC}"
    echo -e "${CYAN}==========================================${NC}"
}

# Function to list baselines
list_baselines() {
    local output_dir="$1"
    
    echo -e "${CYAN}Available Baselines:${NC}"
    echo "===================="
    
    local found=false
    for dir in "$output_dir"/*_assessment; do
        if [ -d "$dir/app_data_baseline" ]; then
            found=true
            local pkg_name=$(basename "$dir" | sed 's/_assessment$//')
            local metadata_file="$dir/baseline_metadata.txt"
            
            echo -e "${GREEN}• $pkg_name${NC}"
            if [ -f "$metadata_file" ]; then
                echo "  $(grep 'Created:' "$metadata_file" || echo 'Created: unknown')"
                echo "  $(grep 'App Version:' "$metadata_file" || echo 'App Version: unknown')"
            fi
            echo ""
        fi
    done
    
    if [ "$found" = false ]; then
        echo "(no baselines found)"
        echo ""
        echo "Create a baseline with: $0 <package_name> -b"
    fi
}

# Parse arguments
VERBOSE=false
PACKAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -o|--output)
            OUTPUT_BASE_DIR="$2"
            shift 2
            ;;
        -b|--baseline)
            ACTION="baseline"
            shift
            ;;
        -c|--compare)
            ACTION="compare"
            shift
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
        *)
            if [ -z "$PACKAGE" ]; then
                PACKAGE="$1"
            else
                echo -e "${RED}Unexpected argument: $1${NC}"
                usage
            fi
            shift
            ;;
    esac
done

# Execute action
case $ACTION in
    list)
        list_baselines "$OUTPUT_BASE_DIR"
        ;;
    baseline)
        if [ -z "$PACKAGE" ]; then
            echo -e "${RED}[!] Package name required.${NC}"
            usage
        fi
        check_adb
        verify_package "$PACKAGE"
        create_baseline "$PACKAGE" "$OUTPUT_BASE_DIR"
        ;;
    compare)
        if [ -z "$PACKAGE" ]; then
            echo -e "${RED}[!] Package name required.${NC}"
            usage
        fi
        check_adb
        verify_package "$PACKAGE"
        compare_to_baseline "$PACKAGE" "$OUTPUT_BASE_DIR"
        ;;
esac
