# update-ipsec-mikrotik.ps1

if ($args.Count -eq 0) {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <IPsec-xauth-password>" -ForegroundColor Red
    exit 1
}

$PASSWORD = $args[0]
$CMD = "/ip ipsec identity set [find peer=`"mynet.sitechcloud.com`"] password=`"$PASSWORD`""

& ssh admin@192.168.11.1 $CMD

if ($LASTEXITCODE -eq 0) {
    Write-Host "IPsec xauth password update succeeded!" -ForegroundColor Green
} else {
    Write-Host "Update failed!" -ForegroundColor Red
    exit 1
}
