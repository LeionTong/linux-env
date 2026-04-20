#!/bin/bash

# ================================================================================
#                     convert_forms_all_to_md.sh
#                 Microsoft Office to Markdown Converter
# ================================================================================
#
# SYNOPSIS
#     Recursively finds .docx, .xlsx, .ppt, and .pptx files and converts them to
#     Markdown using `uvx markitdown`.
#
# DESCRIPTION
#     This script searches the specified directory or file for Microsoft Office
#     files and converts each one to a .md file in the same location.
#
# SYNTAX
#     ./convert_forms_all_to_md.sh [OPTIONS] [PATH]
#
# OPTIONS
#     -h, --help           Show this help message
#     -r, --no-recurse     Do not search subdirectories recursively
#     -f, --force          Overwrite existing .md files
#     -s, --skip           Skip conversion if .md already exists (default)
#
# EXAMPLES
#     ./convert_forms_all_to_md.sh                      # Current directory (recursive)
#     ./convert_forms_all_to_md.sh /path/to/dir         # Specific directory
#     ./convert_forms_all_to_md.sh /path/to/file.docx   # Specific file
#     ./convert_forms_all_to_md.sh -r /path/to/dir      # No recursion
#     ./convert_forms_all_to_md.sh -f /path/to/dir      # Force overwrite
#     ./convert_forms_all_to_md.sh -h                   # Show help
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
                    convert_forms_all_to_md.sh
                    Microsoft Office to Markdown Converter
================================================================================

SYNOPSIS
    Recursively finds .docx, .xlsx, .ppt, and .pptx files and converts them to
    Markdown format using `uvx markitdown`.

SYNTAX
    ./convert_forms_all_to_md.sh [OPTIONS] [PATH]

DESCRIPTION
    This script searches the specified directory or file for Microsoft Office
    files and converts each one to a .md file in the same location with the
    same base name. It uses `uvx markitdown` for the conversion.

OPTIONS
    -h, --help
        Display this help information and exit.

    -r, --no-recurse
        Do not search subdirectories recursively.
        By default, the script searches all subdirectories.

    -f, --force
        Overwrite existing .md files if they already exist.
        By default, existing files are skipped.

    -s, --skip
        Skip conversion if the target .md file already exists.
        This is the default behavior.

ARGUMENTS
    PATH
        Specifies the target directory or file path to search for Office files.
        - If PATH is a file: converts that specific file if it's an Office format
        - If PATH is a directory: converts all Office files in that directory
        - If PATH is omitted: uses the current directory (.)
        - Can be relative or absolute path

SUPPORTED FORMATS
    Input formats:
        - .docx  (Word documents)
        - .xlsx  (Excel spreadsheets)
        - .ppt   (PowerPoint presentations - legacy)
        - .pptx  (PowerPoint presentations)

    Output format:
        - .md    (Markdown)

EXAMPLES
    Example 1: Convert all Office files in current directory (recursive)
        ./convert_forms_all_to_md.sh

    Example 2: Convert all Office files in a specific directory
        ./convert_forms_all_to_md.sh /path/to/documents

    Example 3: Convert a specific file
        ./convert_forms_all_to_md.sh /path/to/report.docx

    Example 4: Convert files only in the specified directory (no recursion)
        ./convert_forms_all_to_md.sh -r /path/to/documents

    Example 5: Force overwrite existing .md files
        ./convert_forms_all_to_md.sh -f /path/to/documents

    Example 6: Display help
        ./convert_forms_all_to_md.sh -h
        ./convert_forms_all_to_md.sh --help

CONVERSION PROCESS
    1. Primary: Uses `uvx --from "markitdown[all]" markitdown` to convert files
    2. Note: PowerPoint COM fallback is Windows-only (not available in shell script)

OUTPUT
    - Converted .md files are saved in the same directory as the source files
    - Existing .md files are skipped by default (configurable with -f flag)
    - Summary statistics shown at the end (Success/Failed/Skipped counts)

EXIT CODES
    0   - All operations completed successfully
    1   - Error: invalid arguments, no files found, or conversion failed

REQUIREMENTS
    - Bash 4.0 or later
    - uvx installed (for markitdown)
    - Python with markitdown package installed

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
        *.docx|*.xlsx|*.ppt|*.pptx)
            FILES="$TARGET_PATH"
            echo -e "${CYAN}Processing file: ${TARGET_PATH}${NC}"
            ;;
        *)
            echo -e "${RED}Error: Not an Office file: ${TARGET_PATH}${NC}" >&2
            echo "Supported formats: .docx, .xlsx, .ppt, .pptx" >&2
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
    FILES=$(find "$TARGET_PATH" $FIND_RECURSE -type f \( -name "*.docx" -o -name "*.xlsx" -o -name "*.ppt" -o -name "*.pptx" \))
else
    echo -e "${RED}Error: Invalid path: ${TARGET_PATH}${NC}" >&2
    exit 1
fi

if [ -z "$FILES" ]; then
    echo -e "${YELLOW}No Office files found.${NC}"
    exit 0
fi

FILE_COUNT=$(echo "$FILES" | wc -l)
echo -e "${GRAY}  Found ${FILE_COUNT} Office file(s)${NC}"

if ! command -v uvx &> /dev/null; then
    echo -e "${RED}Error: uvx is not installed or not in PATH.${NC}" >&2
    echo "Please install it using: pip install uv" >&2
    exit 1
fi

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
    output_path="${dirname}/${filename_no_ext}.md"

    if [ "$SKIP_EXISTING" = true ] && [ -f "$output_path" ]; then
        echo -e "${YELLOW}  [Skip] ${filename} (Target exists)${NC}"
        ((SKIPPED++))
        continue
    fi

    echo -e "  [Convert] ${filename} ..."

    if uvx --from "markitdown[all]" markitdown "$input_path" -o "$output_path" 2>/dev/null; then
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