# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Use powerline
USE_POWERLINE="true"
# Has weird character width
# Example:
#    is not a diamond
HAS_WIDECHARS="false"
# Source manjaro-zsh-configuration
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
  source /usr/share/zsh/manjaro-zsh-config
fi
# Use manjaro zsh prompt
if [[ -e /usr/share/zsh/manjaro-zsh-prompt ]]; then
  source /usr/share/zsh/manjaro-zsh-prompt
fi



# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

#---------LEION---------#
#. ~/.prox

# [Docker]
function img_push() {
# 在本地主机上推送镜像到内网registry
	for image in "${images[@]}"; do
	    # docker login harbor.example.com -u admin -p Harbor12345 # 登录harbor仓库
	    harbor_image="10.86.12.11:20200/leitong/${image}"  # 重新标记镜像，添加仓库地址前缀
	    docker tag $image $harbor_image
	    docker push $harbor_image  # 推送镜像到harbor
	    docker rmi $harbor_image  # 清理本地标记的镜像
	done
}
function img_pull() {
# 在离线服务器上拉取内网registry的镜像
	for image in "${images[@]}"; do
	    harbor_image="10.86.12.11:20200/leitong/${image}"
	    docker pull $harbor_image
	    docker tag $harbor_image $image
	    docker rmi $harbor_image
	done
}

# nvm
source /usr/share/nvm/init-nvm.sh
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node/

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH=/home/leion/.opencode/bin:$PATH

# OpenClaw Completion
source "/home/leion/.openclaw/completions/openclaw.zsh"

