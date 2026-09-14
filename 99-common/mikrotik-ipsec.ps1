# update-ipsec-mikrotik.ps1

$RouterIP = "192.168.11.1"
$Username = "admin"
$PeerName = "mynet.sitechcloud.com"

if ($args.Count -eq 0) {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host " .\$($MyInvocation.MyCommand.Name) <password> # Update IPsec password safely" -ForegroundColor Gray
    Write-Host " .\$($MyInvocation.MyCommand.Name) --start   # Enable IPsec peer" -ForegroundColor Gray
    Write-Host " .\$($MyInvocation.MyCommand.Name) --stop    # Disable IPsec peer" -ForegroundColor Gray
    Write-Host " .\$($MyInvocation.MyCommand.Name) --status  # Print router status info" -ForegroundColor Gray
    exit 1
}

$Action = $args[0]
$sshTarget = "$Username@$RouterIP"
$disableCmd = "/ip ipsec peer disable [find name=`"$PeerName`"]"
$enableCmd = "/ip ipsec peer enable [find name=`"$PeerName`"]"

function Run-SSHCommand {
    param([string]$Cmd, [string]$Desc)
    Write-Host "[INFO] $Desc..." -ForegroundColor Yellow
    $output = & ssh $sshTarget $Cmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] $Desc failed." -ForegroundColor Red
        if ($output) { Write-Host "Output: $output" }
        exit 1
    }
    Write-Host "[OK] $Desc succeeded." -ForegroundColor Green
    if ($output) {
        Write-Host "Result:"
        Write-Host ($output -join "`n")
    }
}

switch ($Action) {
    "--stop" {
        Run-SSHCommand -Cmd $disableCmd -Desc "Disabling IPsec peer"
    }
    "--start" {
        Run-SSHCommand -Cmd $enableCmd -Desc "Enabling IPsec peer"
    }
    "--status" {
        Write-Host "[STATUS MODE] Fetching router information..." -ForegroundColor Cyan

        $commands = @(
            "/ip/ipsec/peer/print",
            "/ip/address/print",
            "/ip/route/print",
            "/ip/firewall/connection/print",
            "/system/script/print",
            "/system/scheduler/print"
	    "/ip/ipsec/active-peers/print"
            "/ip/ipsec/installed-sa/print"
        )

        foreach ($cmd in $commands) {
            Write-Host "`n[INFO] Executing: $cmd" -ForegroundColor Yellow
            $output = & ssh $sshTarget $cmd 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Command failed." -ForegroundColor Red
                if ($output) { Write-Host "Output: $output" }
            } else {
                if ($output) {
                    Write-Host ($output -join "`n")
                } else {
                    Write-Host "<no output>"
                }
            }
        }

        Write-Host "`n[SUCCESS] Status information retrieved." -ForegroundColor Green
    }
    default {
        # Treat as password update
        $PASSWORD = $Action
        $setCmd = "/ip ipsec identity set [find peer=`"$PeerName`"] password=`"$PASSWORD`""

        # Step 1: Stop
        Run-SSHCommand -Cmd $disableCmd -Desc "Stopping peer before update"

        # Step 2: Update
        Write-Host "[INFO] Updating IPsec identity password..." -ForegroundColor Yellow
        $output = & ssh $sshTarget $setCmd 2>&1
        if ($LASTEXITCODE -ne 0 -or ($output -join "`n") -match 'syntax error|error|invalid|failure') {
            Write-Host "[ERROR] Password update failed!" -ForegroundColor Red
            if ($output) { Write-Host "Output: $output" }
            # Try to recover
            & ssh $sshTarget $enableCmd *>$null
            exit 1
        }
        Write-Host "[OK] Password updated successfully." -ForegroundColor Green

        # Step 3: Start
        Run-SSHCommand -Cmd $enableCmd -Desc "Starting peer after update"

        Write-Host ""
        Write-Host "[SUCCESS] Full update cycle completed." -ForegroundColor Green
    }
}
