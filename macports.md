# https://cn.v2ex.com/t/1002670

## 安装时注意事项
断开网络（准备安装，不然会卡）

a、正常断开网络，安装下载的安装包。

b、如果忘了断网，那么需要强制退出

如果步骤一没断网成功会导致安装卡住，如果卡住了，需要强制退出软件
首先使用option+command+esc打开强制退出应用程序窗口，选择强制退出安装程序
然后执行ps aux | grep install 找到MacPorts的安装程序，kill -9 直接删掉，最后再断开网络重新安装。

## 更换镜像源
正确姿势：
/opt/local/etc/macports/sources.conf: 修改一个参数：
rsync://pek.cn.rsync.macports.org/macports/release/tarballs/ports.tar [default]

/opt/local/etc/macports/macports.conf: 修改三个参数
rsync_server pek.cn.rsync.macports.org
rsync_dir macports/release/tarballs/base.tar
preferred_hosts *.cn.*.macports.org

## 额外
macports 默认的镜像列表在 https://github.com/macports/macports-ports/blob/master/_resources/port1.0/fetch/archive_sites.tcl

macports.conf 中 rsync_server 设置的是 base （ port 命令主体） 的镜像。

sources.conf 设置 ports 文件（软件如何打包的定义文件 Portfile ） 镜像。

archive_sites.conf 对应的是一个软件编译后的预编译文件，类似 Homebrew bottle 。

macports.confg 中 preferred_hosts 不是很确定是否影响上边全部，但肯定会影响 distfiles 获取，从源码编译软件时去哪里拉取源码。（ MacPorts 不直接使用 github 等仓库中软件的源码，自己的 distfiles 优先。）
