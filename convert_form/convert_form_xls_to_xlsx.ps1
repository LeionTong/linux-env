<#
.SYNOPSIS
    Batch converts .xls files to .xlsx using Excel COM Object.

.DESCRIPTION
    This script searches the specified directory or file for legacy Excel .xls
    files and converts them to modern .xlsx format. It handles path length
    issues and special characters by using temporary files.

.SYNTAX
    .\convert_form_xls_to_xlsx.ps1 [OPTIONS] [PATH]

.OPTIONS
    -h, --help           Show this help message
    -r, --no-recurse     Do not search subdirectories recursively
    -f, --force          Overwrite existing .xlsx files
    -s, --skip           Skip conversion if .xlsx already exists (default)

.EXAMPLES
    .\convert_form_xls_to_xlsx.ps1                      # Script directory (recursive)
    .\convert_form_xls_to_xlsx.ps1 C:\Spreadsheets      # Specific directory
    .\convert_form_xls_to_xlsx.ps1 C:\Docs\file.xls     # Specific file
    .\convert_form_xls_to_xlsx.ps1 -r C:\Spreadsheets   # No recursion
    .\convert_form_xls_to_xlsx.ps1 -f C:\Spreadsheets   # Force overwrite
    .\convert_form_xls_to_xlsx.ps1 -h                   # Show help

.REQUIREMENTS
    Microsoft Excel installed (for COM Object)
#>

# ================================================================================
#                     convert_form_xls_to_xlsx.ps1
#                 Legacy Excel (.xls) to Excel (.xlsx) Converter
# ================================================================================

$CYAN = 'Cyan'
$GREEN = 'Green'
$YELLOW = 'Yellow'
$RED = 'Red'
$GRAY = 'DarkGray'

$xlOpenXMLWorkbook = 51

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
                    convert_form_xls_to_xlsx.ps1
                    Legacy Excel (.xls) to Excel (.xlsx) Converter
================================================================================

SYNOPSIS
    Batch converts .xls files to .xlsx using Excel COM Object.

SYNTAX
    .\convert_form_xls_to_xlsx.ps1 [OPTIONS] [PATH]

DESCRIPTION
    This script searches the specified directory or file for legacy Excel .xls
    files and converts them to modern .xlsx format. It handles path length
    issues and special characters by using temporary files.

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
        - If PATH is omitted: uses the script directory
        - Can be relative or absolute path

EXAMPLES
    Example 1: Convert all .xls files in script directory (recursive)
        .\convert_form_xls_to_xlsx.ps1

    Example 2: Convert all .xls files in a specific directory
        .\convert_form_xls_to_xlsx.ps1 C:\Spreadsheets

    Example 3: Convert a specific file
        .\convert_form_xls_to_xlsx.ps1 C:\Docs\report.xls

    Example 4: Convert files only in the specified directory (no recursion)
        .\convert_form_xls_to_xlsx.ps1 -r C:\Spreadsheets

    Example 5: Force overwrite existing .xlsx files
        .\convert_form_xls_to_xlsx.ps1 -f C:\Spreadsheets

    Example 6: Display help
        .\convert_form_xls_to_xlsx.ps1 -h
        .\convert_form_xls_to_xlsx.ps1 --help

REQUIREMENTS
    - PowerShell 5.1 or later
    - Microsoft Excel installed (for COM Object)

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
$supportedExtension = '.xls'

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
        Write-Host "Error: Not a .xls file: ${TARGET_PATH}" -ForegroundColor $RED
        Write-Host "Supported format: .xls" -ForegroundColor $GRAY
        exit 1
    }
}

if ($files.Count -eq 0) {
    Write-Host "No .xls files found." -ForegroundColor $YELLOW
    exit 0
}

Write-Host "  Found $($files.Count) .xls file(s)" -ForegroundColor $GRAY

Write-Host "Initializing Excel Application..." -ForegroundColor $CYAN
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    try {
        $excel.DisplayAlerts = $false
    }
    catch {
    }
}
catch {
    Write-Host "Cannot start Excel Application. Please ensure Microsoft Excel is installed." -ForegroundColor $RED
    exit 1
}

$converted = @()
$failed = @()
$skipped = @()

try {
    foreach ($file in $files) {
        $src = $file.FullName
        $dst = [System.IO.Path]::ChangeExtension($src, '.xlsx')

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

        $wb = $null
        $tempSrc = $null
        $tempDst = $null

        try {
            $tempGuid = [System.Guid]::NewGuid().ToString()
            $tempPath = [System.IO.Path]::GetTempPath()
            $tempSrc = Join-Path $tempPath "${tempGuid}.xls"
            $tempDst = Join-Path $tempPath "${tempGuid}.xlsx"

            Copy-Item -LiteralPath $src -Destination $tempSrc -Force

            $wb = $excel.Workbooks.Open($tempSrc, 0, $true)
            $wb.SaveAs($tempDst, $xlOpenXMLWorkbook)
            $wb.Close($false)
            $wb = $null

            Move-Item -LiteralPath $tempDst -Destination $dst -Force

            Write-Host "    Success" -ForegroundColor $GREEN
            $converted += $dst
        }
        catch {
            Write-Host "    Failed" -ForegroundColor $RED
            Write-Host "    Error: $_" -ForegroundColor $RED
            $failed += $src
            if ($wb) {
                try { $wb.Close($false) } catch {}
            }
        }
        finally {
            if ($wb) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) | Out-Null
                Remove-Variable wb -ErrorAction SilentlyContinue
            }
            if ($tempSrc -and (Test-Path -LiteralPath $tempSrc)) {
                Remove-Item -LiteralPath $tempSrc -Force -ErrorAction SilentlyContinue
            }
            if ($tempDst -and (Test-Path -LiteralPath $tempDst)) {
                Remove-Item -LiteralPath $tempDst -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
finally {
    Write-Host "`nCleaning up resources..." -ForegroundColor $CYAN
    if ($excel) {
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        Remove-Variable excel -ErrorAction SilentlyContinue
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