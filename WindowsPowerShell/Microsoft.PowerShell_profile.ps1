# oh-my-posh设置：PowerShell 启动时随机选择主题并初始化
# 脚本位置：~/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1
# 主题下载地址：https://github.com/JanDeDobbeleer/oh-my-posh/releases
# 主题目录：~/Documents/WindowsPowerShell/ohmyposh/themes (需要手动创建)

$themesPath = "~/Documents/WindowsPowerShell/ohmyposh/themes"
$themes = Get-ChildItem -Path $themesPath -Filter "*.omp.*" | Select-Object -ExpandProperty Name
$theme = $themes | Get-Random
$themeFullPath = Join-Path -Path $themesPath -ChildPath $theme

oh-my-posh init pwsh --config $themeFullPath | Invoke-Expression



# 代理配置：
$env:HTTP_PROXY = "http://127.0.0.1:7890"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
$env:ALL_PROXY = "http://127.0.0.1:7890"


