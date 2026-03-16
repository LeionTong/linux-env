!/bin/bash

set -euo pipefail


## 获取vscode客户端版本
# code --version
commit_id=ce099c1ed25d9eb3076c11e4a280f3eb52b4fbeb

## 下载包，放到 ~/.vscode-server/ 目录下
cd ~/.vscode-server/
curl -L https://vscode.download.prss.microsoft.com/dbazure/download/stable/${commit_id}/vscode-server-linux-x64.tar.gz -o vscode-server-linux-x64.tar.gz
curl -L https://vscode.download.prss.microsoft.com/dbazure/download/stable/${commit_id}/vscode_cli_alpine_x64_cli.tar.gz -o vscode_cli_alpine_x64_cli.tar.gz

## 预清理（可选）
# cd ~/.vscode-server/
# rm -rf ./cli/servers/Stable-*
# rm -f ./.cli.*
# rm -f ./code-*

## 解压包
cd ~/.vscode-server/
mkdir -p ~/.vscode-server/cli/servers/Stable-${commit_id}/
tar xf vscode-server-linux-x64.tar.gz -C ~/.vscode-server/cli/servers/Stable-${commit_id}/
mv ~/.vscode-server/cli/servers/Stable-${commit_id}/vscode-server-linux-x64 ~/.vscode-server/cli/servers/Stable-${commit_id}/server
rm -f vscode-server-linux-x64.tar.gz

cd ~/.vscode-server/
tar xf vscode_cli_alpine_x64_cli.tar.gz -C ~/.vscode-server/
mv code code-${commit_id}
rm -f vscode_cli_alpine_x64_cli.tar.gz

# 确保权限
chmod +x ~/.vscode-server/code-*
chmod -R 755 ~/.vscode-server/
