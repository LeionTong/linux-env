@echo off
:: 使用系统默认ANSI编码（解决中文乱码）

:: 检查管理员权限
fltmc >nul 2>&1 || (
    echo 警告：扫描系统盘需要管理员权限！
    echo 请右键点击本脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

:: 配置ClamAV路径（可修改为实际路径）
set "CLAMAV_PATH=C:\clamav\"
echo 正在切换到ClamAV目录：%CLAMAV_PATH%...
cd /d "%CLAMAV_PATH%" || (
    echo 错误：未找到目录 %CLAMAV_PATH%，请检查路径
    pause
    exit /b 1
)

:: 更新病毒库并检查结果
echo.
echo ==============================================
echo 开始更新病毒库...（需网络连接）
echo ==============================================
:: 执行更新并记录返回码（0为基础成功标志）
.\freshclam.exe --config-file=./freshclam.conf
set "UPDATE_RET=%errorlevel%"

:: 提取日志中最后一次更新的段落（以分隔线为标志）
:: 查找最后一个"--------------------------------------"的位置
set "LOG_FILE=freshclam.log"
set "SEPARATOR=--------------------------------------"
set "LAST_SECTION="

:: 逐行读取日志，记录最后分隔线后的内容
for /f "delims=" %%a in (%LOG_FILE%) do (
    if "%%a"=="%SEPARATOR%" (
        set "LAST_SECTION="  :: 遇到新分隔线，重置临时变量
    ) else (
        if defined LAST_SECTION (
            set "LAST_SECTION=!LAST_SECTION!%%a"  :: 累加分隔线后的内容
        )
    )
    :: 当遇到分隔线时，激活后续行的累加
    if "%%a"=="%SEPARATOR%" set "LAST_SECTION=1"
)

:: 检查最后更新段落中三个数据库的状态
set "DAILY_OK=0"
set "MAIN_OK=0"
set "BYTECODE_OK=0"

:: 检查daily.cvd状态（up-to-date或updated）
echo !LAST_SECTION! | findstr /i "daily.cvd database is up-to-date" >nul 2>&1 && set "DAILY_OK=1"
echo !LAST_SECTION! | findstr /i "daily.cvd updated" >nul 2>&1 && set "DAILY_OK=1"

:: 检查main.cvd状态（仅up-to-date，main库很少更新）
echo !LAST_SECTION! | findstr /i "main.cvd database is up-to-date" >nul 2>&1 && set "MAIN_OK=1"

:: 检查bytecode.cld状态（up-to-date或updated）
echo !LAST_SECTION! | findstr /i "bytecode.cld database is up-to-date" >nul 2>&1 && set "BYTECODE_OK=1"
echo !LAST_SECTION! | findstr /i "bytecode.cld updated" >nul 2>&1 && set "BYTECODE_OK=1"

:: 综合判断更新是否成功
if %UPDATE_RET% equ 0 (
    if %DAILY_OK% equ 1 if %MAIN_OK% equ 1 if %BYTECODE_OK% equ 1 (
        echo 病毒库更新成功（所有数据库均为最新状态），继续执行...
    ) else (
        echo 错误：更新返回码正常，但部分数据库未成功更新！
        echo 最后更新段落状态：
        echo "!LAST_SECTION!"
        echo 请查看日志（freshclam.log）排查问题...
        notepad %LOG_FILE%
        pause
        exit /b 1
    )
) else (
    echo 错误：病毒库更新失败（返回码：%UPDATE_RET%）！
    echo 最后更新段落状态：
    echo "!LAST_SECTION!"
    echo 请查看日志（freshclam.log）排查问题...
    notepad %LOG_FILE%
    pause
    exit /b 1
)

:: 尝试启动clamd并判断扫描方式
echo.
echo ==============================================
echo 正在检查clamd守护进程（用于高效扫描）...
echo ==============================================
set "USE_CLAMDSCAN=1"  :: 默认优先使用clamdscan
tasklist | find /i "clamd.exe" >nul 2>&1
if %errorlevel% equ 0 (
    echo 已发现运行中的clamd进程，将使用clamdscan（多线程快速扫描）
) else (
    echo 未发现clamd进程，尝试启动...
    start "" "%CLAMAV_PATH%\clamd.exe"
    timeout /t 3 /nobreak >nul  :: 等待启动
    tasklist | find /i "clamd.exe" >nul 2>&1 || (
        echo 警告：clamd启动失败！将切换到clamscan（独立扫描，速度较慢）
        set "USE_CLAMDSCAN=0"  :: 切换为clamscan
    )
)

:: 根据判断执行对应扫描
echo.
echo ==============================================
if %USE_CLAMDSCAN% equ 1 (
    echo 开始使用clamdscan扫描C盘（多线程，较快）...
    echo （扫描期间请勿关闭命令窗口或clamd进程）
    .\clamdscan.exe --multiscan --log=clamdscan.log C:\
    set "SCAN_LOG=clamdscan.log"
) else (
    echo 开始使用clamscan扫描C盘（独立模式，较慢）...
    echo （扫描可能需要数小时，请耐心等待）
    .\clamscan.exe -r -i --bell --log=clamscan.log C:\
    set "SCAN_LOG=clamscan.log"
)
echo ==============================================

:: 查看扫描日志
echo.
echo ==============================================
echo 扫描完成，打开日志（%SCAN_LOG%）...
echo （日志中"FOUND"表示发现威胁，"OK"表示无异常）
echo ==============================================
notepad %SCAN_LOG%

:: 清理clamd进程（若使用了clamdscan）
if %USE_CLAMDSCAN% equ 1 (
    taskkill /f /im clamd.exe >nul 2>&1
    echo 已关闭clamd守护进程，释放资源
)

echo.
echo 所有操作完成，按任意键退出...
pause >nul