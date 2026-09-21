#----------------------------------------------------------#
# UTF-8 编码修复：解决 pwsh 中文乱码（gb2312 -> UTF-8）
# 仅作用于当前 pwsh 会话的控制台编码，不改系统级代码页
# 2026-09-04: [Console]::OutputEncoding 原本被系统 OEMCP 936 顶成 gb2312
# 导致 UTF-8 字节被按 GB2312 解读而乱码；此处统一为 UTF-8。
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)   # UTF-8 无 BOM
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding          = [System.Text.UTF8Encoding]::new($false)   # 管道/脚本输出
if ($PSVersionTable.PSVersion.Major -ge 6 -and $env:OS -like 'Windows*') {
    # cmd 子进程（如 chcp 查验）也切到 65001，保持整条控制台编码一致
    chcp 65001 > $null 2>&1
}
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
$env:NO_PROXY = "127.0.0.1,localhost"
$env:no_proxy = "127.0.0.1,localhost"
# Node 24+：让 node 内置 fetch / undici 走上面的代理（dsh 等运行时 API 请求）
$env:NODE_USE_ENV_PROXY = "1"
#----------------------------------------------------------#
# Git Bash 快速启动：在 PowerShell 里直接敲 git-bash 进入纯 Git Bash
function git-bash {
    & 'C:\Program Files\Git\bin\bash.exe' -l
}
#----------------------------------------------------------#
