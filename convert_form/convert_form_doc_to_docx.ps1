<#
.SYNOPSIS
    Batch converts .doc files to .docx using Word COM Object.

.DESCRIPTION
    This script searches the specified directory or file for legacy Word .doc
    files and converts them to modern .docx format. It includes resource
    cleanup and skips conversion if the target file already exists.

.SYNTAX
    .\convert_form_doc_to_docx.ps1 [OPTIONS] [PATH]

.OPTIONS
    -h, --help           Show this help message
    -r, --no-recurse     Do not search subdirectories recursively
    -f, --force          Overwrite existing .docx files
    -s, --skip           Skip conversion if .docx already exists (default)

.EXAMPLES
    .\convert_form_doc_to_docx.ps1                      # Script directory (recursive)
    .\convert_form_doc_to_docx.ps1 C:\Documents         # Specific directory
    .\convert_form_doc_to_docx.ps1 C:\Docs\file.doc     # Specific file
    .\convert_form_doc_to_docx.ps1 -r C:\Documents      # No recursion
    .\convert_form_doc_to_docx.ps1 -f C:\Documents      # Force overwrite
    .\convert_form_doc_to_docx.ps1 -h                   # Show help

.REQUIREMENTS
    Microsoft Word installed (for COM Object)
#>

# ================================================================================
#                     convert_form_doc_to_docx.ps1
#                 Legacy Word (.doc) to Word (.docx) Converter
# ================================================================================

$CYAN = 'Cyan'
$GREEN = 'Green'
$YELLOW = 'Yellow'
$RED = 'Red'
$GRAY = 'DarkGray'

$wdFormatXMLDocument = 12
$wdDoNotSaveChanges = 0
$wdAlertsNone = 0

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
    Write-Host @"
================================================================================
                    convert_form_doc_to_docx.ps1
                    Legacy Word (.doc) to Word (.docx) Converter
================================================================================

SYNOPSIS
    Batch converts .doc files to .docx using Word COM Object.

SYNTAX
    .\convert_form_doc_to_docx.ps1 [OPTIONS] [PATH]

DESCRIPTION
    This script searches the specified directory or file for legacy Word .doc
    files and converts them to modern .docx format. It includes resource
    cleanup and skips conversion if the target file already exists.

OPTIONS
    -h, --help
        Display this help information and exit.

    -r, --no-recurse
        Do not search subdirectories recursively.
        By default, the script searches all subdirectories.

    -f, --force
        Overwrite existing .docx files if they already exist.
        By default, existing files are skipped.

    -s, --skip
        Skip conversion if the target .docx file already exists.
        This is the default behavior.

ARGUMENTS
    PATH
        Specifies the target directory or file path to search for .doc files.
        - If PATH is a file: converts that specific file if it's a .doc file
        - If PATH is a directory: converts all .doc files in that directory
        - If PATH is omitted: uses the script directory
        - Can be relative or absolute path

EXAMPLES
    Example 1: Convert all .doc files in script directory (recursive)
        .\convert_form_doc_to_docx.ps1

    Example 2: Convert all .doc files in a specific directory
        .\convert_form_doc_to_docx.ps1 C:\Documents

    Example 3: Convert a specific file
        .\convert_form_doc_to_docx.ps1 C:\Docs\report.doc

    Example 4: Convert files only in the specified directory (no recursion)
        .\convert_form_doc_to_docx.ps1 -r C:\Documents

    Example 5: Force overwrite existing .docx files
        .\convert_form_doc_to_docx.ps1 -f C:\Documents

    Example 6: Display help
        .\convert_form_doc_to_docx.ps1 -h
        .\convert_form_doc_to_docx.ps1 --help

REQUIREMENTS
    - PowerShell 5.1 or later
    - Microsoft Word installed (for COM Object)

================================================================================
"@
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
$supportedExtension = '.doc'

if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
    Write-Host "Searching for files in: ${TARGET_PATH}" -ForegroundColor $CYAN
    $searchOption = if ($RECURSE) { 'AllDirectories' } else { 'TopDirectoryOnly' }
    Write-Host "  ($(if ($RECURSE) { 'recursive search' } else { 'non-recursive' }))" -ForegroundColor $GRAY
    $files = @( [System.IO.Directory]::GetFiles($resolvedPath, "*$supportedExtension", $searchOption) | ForEach-Object { Get-Item -LiteralPath $_ } )
} elseif (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
    $ext = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
    if ($ext -eq $supportedExtension) {
        $files = @( Get-Item -LiteralPath $resolvedPath )
        Write-Host "Processing file: ${TARGET_PATH}" -ForegroundColor $CYAN
    } else {
        Write-Host "Error: Not a .doc file: ${TARGET_PATH}" -ForegroundColor $RED
        Write-Host "Supported format: .doc" -ForegroundColor $GRAY
        exit 1
    }
}

if ($files.Count -eq 0) {
    Write-Host "No .doc files found." -ForegroundColor $YELLOW
    exit 0
}

Write-Host "  Found $($files.Count) .doc file(s)" -ForegroundColor $GRAY

Write-Host "Initializing Word Application..." -ForegroundColor $CYAN
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    try {
        $word.DisplayAlerts = $wdAlertsNone
    }
    catch {
    }
}
catch {
    Write-Host "Cannot start Word Application. Please ensure Microsoft Word is installed." -ForegroundColor $RED
    exit 1
}

$converted = @()
$failed = @()
$skipped = @()

try {
    foreach ($file in $files) {
        $src = $file.FullName
        $dst = [System.IO.Path]::ChangeExtension($src, '.docx')

        if (-not (Test-Path -LiteralPath $src)) {
            Write-Host "  [Error] Source file does not exist: ${src}" -ForegroundColor $RED
            $failed += $src
            continue
        }

        if ($SKIP_EXISTING -and (Test-Path -LiteralPath $dst)) {
            Write-Host "  [Skip] $($file.Name) (Target exists)" -ForegroundColor $YELLOW
            $skipped += $src
            continue
        }

        Write-Host "  [Convert] $($file.Name) ..."

        $doc = $null
        try {
            $doc = $word.Documents.Open($src, $false, $true)
            $doc.SaveAs([ref]$dst, [ref]$wdFormatXMLDocument)
            $doc.Close([ref]$wdDoNotSaveChanges)
            Write-Host "    Success" -ForegroundColor $GREEN
            $converted += $dst
        }
        catch {
            Write-Host "    Failed" -ForegroundColor $RED
            Write-Host "    Error: $_" -ForegroundColor $RED
            $failed += $src
            if ($doc) {
                try { $doc.Close([ref]$wdDoNotSaveChanges) } catch {}
            }
        }
        finally {
            if ($doc) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) | Out-Null
                Remove-Variable doc -ErrorAction SilentlyContinue
            }
        }
    }
}
finally {
    Write-Host "`nCleaning up resources..." -ForegroundColor $CYAN
    if ($word) {
        $word.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
        Remove-Variable word -ErrorAction SilentlyContinue
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

Write-Host ""
Write-Host "=== Conversion Statistics ===" -ForegroundColor $CYAN
Write-Host "Success: $($converted.Count)" -ForegroundColor $GREEN
Write-Host "Failed: $($failed.Count)" -ForegroundColor $RED
Write-Host "Skipped: $($skipped.Count)" -ForegroundColor $YELLOW

if ($failed.Count -gt 0) {
    Write-Host "`nFailed files list:" -ForegroundColor $RED
    $failed | ForEach-Object { Write-Host " - $_" }
    exit 1
}

exit 0