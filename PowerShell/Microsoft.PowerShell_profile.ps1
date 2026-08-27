#----------------------------------------------------------#
# oh-my-posh设置：PowerShell 启动时随机选择主题并初始化
# 脚本位置：~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1
# 主题下载地址：https://github.com/JanDeDobbeleer/oh-my-posh/releases
# 主题目录：~/Documents/PowerShell/ohmyposh/themes (需要手动创建)
$themesPath = "~/Documents/PowerShell/oh-my-posh/themes"
$themes = Get-ChildItem -Path $themesPath -Filter "*.omp.*" | Select-Object -ExpandProperty Name
$theme = $themes | Get-Random
$themeFullPath = Join-Path -Path $themesPath -ChildPath $theme
oh-my-posh init pwsh --config $themeFullPath | Invoke-Expression

#----------------------------------------------------------#
# 代理配置：
$env:HTTP_PROXY = "http://127.0.0.1:7890"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
$env:ALL_PROXY = "http://127.0.0.1:7890"
$env:http_proxy = "http://127.0.0.1:7890"
$env:https_proxy = "http://127.0.0.1:7890"
# 本机/本地直连；其余全进 clash，由 clash 分流（含 aiproxy）
$env:NO_PROXY = "127.0.0.1,localhost"
$env:no_proxy = "127.0.0.1,localhost"
# Node 24+：让 node 内置 fetch / undici 走上面的代理（dsh 等运行时 API 请求）
$env:NODE_USE_ENV_PROXY = "1"
#----------------------------------------------------------#
