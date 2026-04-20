#!/bin/bash

# ================================================================================
#                     convert_form_xls_to_xlsx.sh
#                 Legacy Excel (.xls) to Excel (.xlsx) Converter
# ================================================================================
#
# SYNOPSIS
#     Batch converts .xls files to .xlsx using LibreOffice headless mode.
#
# DESCRIPTION
#     This script searches the specified directory or file for legacy Excel .xls
#     files and converts them to modern .xlsx format.
#
# SYNTAX
#     ./convert_form_xls_to_xlsx.sh [OPTIONS] [PATH]
#
# OPTIONS
#     -h, --help           Show this help message
#     -r, --no-recurse     Do not search subdirectories recursively
#     -f, --force          Overwrite existing .xlsx files
#     -s, --skip           Skip conversion if .xlsx already exists (default)
#
# EXAMPLES
#     ./convert_form_xls_to_xlsx.sh                      # Current directory (recursive)
#     ./convert_form_xls_to_xlsx.sh /path/to/dir         # Specific directory
#     ./convert_form_xls_to_xlsx.sh /path/to/file.xls    # Specific file
#     ./convert_form_xls_to_xlsx.sh -r /path/to/dir      # No recursion
#     ./convert_form_xls_to_xlsx.sh -f /path/to/dir      # Force overwrite
#     ./convert_form_xls_to_xlsx.sh -h                   # Show help
#
# REQUIREMENTS
#     LibreOffice must be installed.
#     Ubuntu/Debian: sudo apt update && sudo apt install libreoffice -y
#     CentOS/RHEL: sudo yum install libreoffice -y
#     macOS: brew install --cask libreoffice
#
# ================================================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m'

show_help() {
    cat << 'EOF'
================================================================================
                    convert_form_xls_to_xlsx.sh
                    Legacy Excel (.xls) to Excel (.xlsx) Converter
================================================================================

SYNOPSIS
    Batch converts .xls files to .xlsx using LibreOffice headless mode.

SYNTAX
    ./convert_form_xls_to_xlsx.sh [OPTIONS] [PATH]

DESCRIPTION
    This script searches the specified directory or file for legacy Excel .xls
    files and converts them to modern .xlsx format using LibreOffice.
    Existing .xlsx files are skipped by default.

OPTIONS
    -h, --help
        Display this help information and exit.

    -r, --no-recurse
        Do not search subdirectories recursively.
        By default, the script searches all subdirectories.

    -f, --force
        Overwrite existing .xlsx files if they already exist.
        By default, existing files are skipped.

    -s, --skip
        Skip conversion if the target .xlsx file already exists.
        This is the default behavior.

ARGUMENTS
    PATH
        Specifies the target directory or file path to search for .xls files.
        - If PATH is a file: converts that specific file if it's a .xls file
        - If PATH is a directory: converts all .xls files in that directory
        - If PATH is omitted: uses the current directory (.)
        - Can be relative or absolute path

EXAMPLES
    Example 1: Convert all .xls files in current directory (recursive)
        ./convert_form_xls_to_xlsx.sh

    Example 2: Convert all .xls files in a specific directory
        ./convert_form_xls_to_xlsx.sh /path/to/spreadsheets

    Example 3: Convert a specific file
        ./convert_form_xls_to_xlsx.sh /path/to/report.xls

    Example 4: Convert files only in the specified directory (no recursion)
        ./convert_form_xls_to_xlsx.sh -r /path/to/spreadsheets

    Example 5: Force overwrite existing .xlsx files
        ./convert_form_xls_to_xlsx.sh -f /path/to/spreadsheets

    Example 6: Display help
        ./convert_form_xls_to_xlsx.sh -h
        ./convert_form_xls_to_xlsx.sh --help

REQUIREMENTS
    - Bash 4.0 or later
    - LibreOffice installed (soffice or libreoffice command)

================================================================================
EOF
}

RECURSE=true
FORCE=false
SKIP_EXISTING=true
TARGET_PATH="."

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--no-recurse)
            RECURSE=false
            shift
            ;;
        -f|--force)
            FORCE=true
            SKIP_EXISTING=false
            shift
            ;;
        -s|--skip)
            SKIP_EXISTING=true
            FORCE=false
            shift
            ;;
        -*)
            echo -e "${RED}Error: Unknown option: $1${NC}" >&2
            echo "Use -h or --help for usage information." >&2
            exit 1
            ;;
        *)
            TARGET_PATH="$1"
            shift
            ;;
    esac
done

if [ ! -e "$TARGET_PATH" ]; then
    echo -e "${RED}Error: Path not found: ${TARGET_PATH}${NC}" >&2
    exit 1
fi

if [ "$RECURSE" = true ]; then
    FIND_RECURSE=""
else
    FIND_RECURSE="-maxdepth 1"
fi

if [ -f "$TARGET_PATH" ]; then
    case "$TARGET_PATH" in
        *.xls)
            FILES="$TARGET_PATH"
            echo -e "${CYAN}Processing file: ${TARGET_PATH}${NC}"
            ;;
        *)
            echo -e "${RED}Error: Not a .xls file: ${TARGET_PATH}${NC}" >&2
            echo "Supported format: .xls" >&2
            exit 1
            ;;
    esac
elif [ -d "$TARGET_PATH" ]; then
    echo -e "${CYAN}Searching for files in: ${TARGET_PATH}${NC}"
    if [ "$RECURSE" = true ]; then
        echo -e "${GRAY}  (recursive search)${NC}"
    else
        echo -e "${GRAY}  (non-recursive)${NC}"
    fi
    FILES=$(find "$TARGET_PATH" $FIND_RECURSE -type f -name "*.xls")
else
    echo -e "${RED}Error: Invalid path: ${TARGET_PATH}${NC}" >&2
    exit 1
fi

if [ -z "$FILES" ]; then
    echo -e "${YELLOW}No .xls files found.${NC}"
    exit 0
fi

FILE_COUNT=$(echo "$FILES" | wc -l)
echo -e "${GRAY}  Found ${FILE_COUNT} .xls file(s)${NC}"

if ! command -v libreoffice &> /dev/null && ! command -v soffice &> /dev/null; then
    echo -e "${RED}Error: libreoffice (or soffice) is not installed.${NC}" >&2
    echo "Please install it using your package manager (e.g., 'sudo apt install libreoffice')." >&2
    exit 1
fi

LO_BIN=$(command -v libreoffice || command -v soffice)

CONVERTED=0
FAILED=0
SKIPPED=0
FAILED_LIST=""

while IFS= read -r input_path; do
    if [ ! -f "$input_path" ]; then
        echo -e "${RED}  [Error] Source file does not exist: $input_path${NC}" >&2
        ((FAILED++))
        continue
    fi

    filename=$(basename -- "$input_path")
    dirname=$(dirname -- "$input_path")
    filename_no_ext="${filename%.*}"
    output_path="${dirname}/${filename_no_ext}.xlsx"

    if [ "$SKIP_EXISTING" = true ] && [ -f "$output_path" ]; then
        echo -e "${YELLOW}  [Skip] ${filename} (Target exists)${NC}"
        ((SKIPPED++))
        continue
    fi

    echo -e "  [Convert] ${filename} ..."

    if "$LO_BIN" --headless --convert-to xlsx --outdir "$dirname" "$input_path" 2>/dev/null; then
        echo -e "${GREEN}    Success${NC}"
        ((CONVERTED++))
    else
        EXIT_CODE=$?
        echo -e "${RED}    Failed (Exit Code ${EXIT_CODE})${NC}"
        ((FAILED++))
        FAILED_LIST="${FAILED_LIST}\n - ${input_path}"
    fi
done <<< "$FILES"

echo ""
echo -e "${CYAN}=== Conversion Statistics ===${NC}"
echo -e "${GREEN}Success: ${CONVERTED}${NC}"
echo -e "${RED}Failed: ${FAILED}${NC}"
echo -e "${YELLOW}Skipped: ${SKIPPED}${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "\n${RED}Failed files list:${NC}"
    echo -e "$FAILED_LIST"
    exit 1
fi

exit 0