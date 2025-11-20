!/bin/bash

set -euo pipefail

## 预清理，可选
cd ~/.vscode-server/
rm -rf ./cli/servers/Stable-*
rm -f ./.cli.*
rm -f ./code-*


# 安装服务端 vscode-server
commit_id=ac4cbdf48759c7d8c3eb91ffe6bb04316e263c57

cd ~/.vscode-server/
# 可以提前下载好，放到 ~/.vscode-server/ 目录下
# curl -L https://vscode.download.prss.microsoft.com/dbazure/download/stable/${commit_id}/vscode-server-linux-x64.tar.gz -o vscode-server-linux-x64.tar.gz
mkdir -p ~/.vscode-server/cli/servers/Stable-${commit_id}/
tar xf vscode-server-linux-x64.tar.gz -C ~/.vscode-server/cli/servers/Stable-${commit_id}/
mv ~/.vscode-server/cli/servers/Stable-${commit_id}/vscode-server-linux-x64 ~/.vscode-server/cli/servers/Stable-${commit_id}/server
rm -f vscode-server-linux-x64.tar.gz

cd ~/.vscode-server/
# 可以提前下载好，放到 ~/.vscode-server/ 目录下
# curl -L https://vscode.download.prss.microsoft.com/dbazure/download/stable/${commit_id}/vscode_cli_alpine_x64_cli.tar.gz -o vscode_cli_alpine_x64_cli.tar.gz
tar xf vscode_cli_alpine_x64_cli.tar.gz -C ~/.vscode-server/
mv code code-${commit_id}
rm -f vscode_cli_alpine_x64_cli.tar.gz

## 确保权限
chmod +x ~/.vscode-server/code-*
chmod -R 755 ~/.vscode-server/
