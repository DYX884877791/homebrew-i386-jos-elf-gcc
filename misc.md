git config --global user.name 'dyx'
git config --global user.email '1437418067@qq.com'


export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890


## 通过 Clash 自动设置
使用 ClashX Meta 时，勾选 设置为系统代理 即可自动写入上述配置，无需手动设置。关闭 ClashX Meta 或取消勾选后，系统代理会自动恢复。

命令行查看当前代理
# 查看系统代理状态
scutil --proxy


## 终端（Terminal、iTerm2 等）默认不读取系统代理，需通过环境变量配置。

常用环境变量
变量名	说明
http_proxy / HTTP_PROXY	HTTP 请求代理
https_proxy / HTTPS_PROXY	HTTPS 请求代理
all_proxy / ALL_PROXY	通用代理（部分工具）
no_proxy / NO_PROXY	不使用代理的地址，多个用逗号分隔
临时设置（当前会话）
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
export all_proxy="socks5://127.0.0.1:7891"
export no_proxy="localhost,127.0.0.1,*.local"
持久化配置（.zshrc）
macOS 默认使用 Zsh，编辑 ~/.zshrc：

nano ~/.zshrc
在文件末尾添加：

# Clash 代理（端口以 ClashX Meta 实际配置为准）
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
export all_proxy="socks5://127.0.0.1:7891"
export no_proxy="localhost,127.0.0.1,*.local"
保存后执行：

source ~/.zshrc
或重新打开终端窗口。

使用 Bash 时
若使用 Bash，编辑 ~/.bash_profile 或 ~/.bashrc，添加相同内容。

取消代理
unset http_proxy https_proxy all_proxy no_proxy
