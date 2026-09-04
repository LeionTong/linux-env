# UTF-8 编码修复：解决 Windows PowerShell 5.1 中文乱码
# 2026-09-04: 5.1 默认 [Console]::OutputEncoding=gb2312，导致 UTF-8 内容乱码
# 此处统一为 UTF-8(无 BOM)。仅作用于本会话控制台，不改系统代码页。
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding  = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
# cmd 子进程一并切到 65001，保持整条控制台编码一致（失败静默忽略）
cmd /c "chcp 65001" | Out-Null
