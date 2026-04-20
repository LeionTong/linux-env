<#
.SYNOPSIS
    Recursively finds .docx, .xlsx, .ppt, and .pptx files and converts them to Markdown using `uvx markitdown`.

.DESCRIPTION
    This script searches the specified directory or file for Microsoft Office
    files and converts each one to a .md file in the same location with the
    same base name. It uses `uvx markitdown` for the conversion.

.SYNTAX
    .\convert_forms_all_to_md.ps1 [OPTIONS] [PATH]

.OPTIONS
    -h, --help           Show this help message
    -r, --no-recurse     Do not search subdirectories recursively
    -f, --force          Overwrite existing .md files
    -s, --skip           Skip conversion if .md already exists (default)

.EXAMPLES
    .\convert_forms_all_to_md.ps1                      # Current directory (recursive)
    .\convert_forms_all_to_md.ps1 C:\Documents         # Specific directory
    .\convert_forms_all_to_md.ps1 C:\Docs\file.docx    # Specific file
    .\convert_forms_all_to_md.ps1 -r C:\Documents      # No recursion
    .\convert_forms_all_to_md.ps1 -f C:\Documents      # Force overwrite
    .\convert_forms_all_to_md.ps1 -h                   # Show help
#>

# ================================================================================
#                     convert_forms_all_to_md.ps1
#                 Microsoft Office to Markdown Converter
# ================================================================================

$CYAN = 'Cyan'
$GREEN = 'Green'
$YELLOW = 'Yellow'
$RED = 'Red'
$GRAY = 'DarkGray'

$RECURSE = $true
$FORCE = $false
$SKIP_EXISTING = $true
$TARGET_PATH = $null
$SHOW_HELP = $false
$UNKNOWN_OPTION = $false
$UNKNOWN_OPTION_NAME = ""

foreach ($arg in $args) {
    switch -Regex ($arg) {
        '^(-h|--help)$' {
            $SHOW_HELP = $true
            break
        }
        '^(-r|--no-recurse)$' {
            $RECURSE = $false
            break
        }
        '^(-f|--force)$' {
            $FORCE = $true
            $SKIP_EXISTING = $false
            break
        }
        '^(-s|--skip)$' {
            $SKIP_EXISTING = $true
            $FORCE = $false
            break
        }
        '^-.*' {
            $UNKNOWN_OPTION = $true
            $UNKNOWN_OPTION_NAME = $arg
            break
        }
        default {
            if (-not $TARGET_PATH) {
                $TARGET_PATH = $arg
            }
        }
    }
}

if ($UNKNOWN_OPTION) {
    Write-Host "Error: Unknown option: $UNKNOWN_OPTION_NAME" -ForegroundColor $RED
    Write-Host "Use -h or --help for usage information." -ForegroundColor $GRAY
    exit 1
}

if ($SHOW_HELP) {
    Write-Host @'
================================================================================
                    convert_forms_all_to_md.ps1
                    Microsoft Office to Markdown Converter
================================================================================

SYNOPSIS
    Recursively finds .docx, .xlsx, .ppt, and .pptx files and converts them to
    Markdown format using uvx markitdown.

SYNTAX
    .\convert_forms_all_to_md.ps1 [OPTIONS] [PATH]

DESCRIPTION
    This script searches the specified directory or file for Microsoft Office
    files and converts each one to a .md file in the same location with the
    same base name. It uses uvx markitdown for the conversion.

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
        - If PATH is omitted: uses the script directory
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
    Example 1: Convert all Office files in script directory (recursive)
        .\convert_forms_all_to_md.ps1

    Example 2: Convert all Office files in a specific directory
        .\convert_forms_all_to_md.ps1 C:\Documents

    Example 3: Convert a specific file
        .\convert_forms_all_to_md.ps1 C:\Docs\report.docx

    Example 4: Convert files only in the specified directory (no recursion)
        .\convert_forms_all_to_md.ps1 -r C:\Documents

    Example 5: Force overwrite existing .md files
        .\convert_forms_all_to_md.ps1 -f C:\Documents

    Example 6: Display help
        .\convert_forms_all_to_md.ps1 -h
        .\convert_forms_all_to_md.ps1 --help

CONVERSION PROCESS
    1. Primary: Uses uvx --from "markitdown[all]" markitdown to convert files
    2. Fallback: For .ppt/.pptx files, uses PowerPoint COM to extract text if
       markitdown fails

OUTPUT
    - Converted .md files are saved in the same directory as the source files
    - Existing .md files are skipped by default (configurable with -f flag)
    - Summary statistics shown at the end (Success/Failed/Skipped counts)

EXIT CODES
    0   - All operations completed successfully
    1   - Error: invalid arguments, no files found, or conversion failed

REQUIREMENTS
    - PowerShell 5.1 or later
    - uvx installed (for markitdown)
    - Python with markitdown package installed
    - Microsoft PowerPoint installed (for PPT fallback on Windows)

================================================================================
'@
    exit 0
}

if (-not $TARGET_PATH) {
    $TARGET_PATH = $PSScriptRoot
}

if (-not (Test-Path -LiteralPath $TARGET_PATH)) {
    Write-Host "Error: Path not found: ${TARGET_PATH}" -ForegroundColor $RED
    exit 1
}

$resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TARGET_PATH)

$files = @()
$supportedExtensions = @('.docx', '.xlsx', '.ppt', '.pptx')

if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
    Write-Host "Searching for files in: ${TARGET_PATH}" -ForegroundColor $CYAN
    $searchOption = if ($RECURSE) { 'AllDirectories' } else { 'TopDirectoryOnly' }
    Write-Host "  ($(if ($RECURSE) { 'recursive search' } else { 'non-recursive' }))" -ForegroundColor $GRAY
    foreach ($ext in $supportedExtensions) {
        $files += @( [System.IO.Directory]::GetFiles($resolvedPath, "*$ext", $searchOption) | ForEach-Object { Get-Item -LiteralPath $_ } )
    }
} elseif (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
    $ext = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
    if ($ext -in $supportedExtensions) {
        $files = @( Get-Item -LiteralPath $resolvedPath )
        Write-Host "Processing file: ${TARGET_PATH}" -ForegroundColor $CYAN
    } else {
        Write-Host "Error: Not an Office file: ${TARGET_PATH}" -ForegroundColor $RED
        Write-Host "Supported formats: .docx, .xlsx, .ppt, .pptx" -ForegroundColor $GRAY
        exit 1
    }
}

if ($files.Count -eq 0) {
    Write-Host "No Office files found." -ForegroundColor $YELLOW
    exit 0
}

Write-Host "  Found $($files.Count) Office file(s)" -ForegroundColor $GRAY

try {
    $uvxCheck = Get-Command uvx -ErrorAction Stop
} catch {
    Write-Host "Error: uvx is not installed or not in PATH." -ForegroundColor $RED
    Write-Host "Please install it using: pip install uv" -ForegroundColor $GRAY
    exit 1
}

$CONVERTED = 0
$FAILED = 0
$SKIPPED = 0
$FAILED_LIST = @()

foreach ($file in $files) {
    $inputPath = $file.FullName
    $outputPath = [System.IO.Path]::ChangeExtension($inputPath, ".md")

    if (-not (Test-Path -LiteralPath $inputPath)) {
        Write-Host "  [Error] Source file does not exist: ${inputPath}" -ForegroundColor $RED
        $FAILED++
        $FAILED_LIST += $inputPath
        continue
    }

    if ($SKIP_EXISTING -and (Test-Path -LiteralPath $outputPath)) {
        Write-Host "  [Skip] $($file.Name) (Target exists)" -ForegroundColor $YELLOW
        $SKIPPED++
        continue
    }

    Write-Host "  [Convert] $($file.Name) ..."

    $isSuccess = $false
    try {
        $output = uvx --from "markitdown[all]" markitdown "$inputPath" -o "$outputPath" 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Success" -ForegroundColor $GREEN
            $CONVERTED++
            $isSuccess = $true
        } else {
            Write-Host "    Failed (Exit Code ${LASTEXITCODE})" -ForegroundColor $RED
            $FAILED++
            $FAILED_LIST += $inputPath
        }
    } catch {
        Write-Host "    Failed (Exit Code $LASTEXITCODE)" -ForegroundColor $RED
        $FAILED++
        $FAILED_LIST += $inputPath
    }

    if (-not $isSuccess -and ($file.Extension -eq '.pptx' -or $file.Extension -eq '.ppt')) {
        Write-Host "    Trying PowerPoint COM fallback..." -ForegroundColor $GRAY
        try {
            $pptApp = New-Object -ComObject PowerPoint.Application
            $msoTrue = -1
            $msoFalse = 0
            $pres = $pptApp.Presentations.Open($inputPath, $msoTrue, $msoFalse, $msoFalse)

            $text = ""
            foreach ($slide in $pres.Slides) {
                $text += "## Slide $($slide.SlideIndex)`n`n"
                foreach ($shape in $slide.Shapes) {
                    if ($shape.HasTextFrame -and $shape.TextFrame.HasText) {
                        $text += $shape.TextFrame.TextRange.Text + "`n"
                    }
                }
                $text += "`n"
            }

            $pres.Close()
            $pptApp.Quit()
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($pptApp) | Out-Null

            $text | Out-File -FilePath $outputPath -Encoding utf8
            Write-Host "    Fallback Success" -ForegroundColor $GREEN
            $CONVERTED++
            $isSuccess = $true
        } catch {
            Write-Host "    Fallback failed" -ForegroundColor $RED
        }
    }
}

Write-Host ""
Write-Host "=== Conversion Statistics ===" -ForegroundColor $CYAN
Write-Host "Success: ${CONVERTED}" -ForegroundColor $GREEN
Write-Host "Failed: ${FAILED}" -ForegroundColor $RED
Write-Host "Skipped: ${SKIPPED}" -ForegroundColor $YELLOW

if ($FAILED -gt 0) {
    Write-Host ""
    Write-Host "Failed files list:" -ForegroundColor $RED
    foreach ($f in $FAILED_LIST) {
        Write-Host " - ${f}"
    }
    exit 1
}

exit 0