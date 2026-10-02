#!/bin/bash

author=233boy

red='\e[31m'
yellow='\e[33m'
green='\e[92m'
none='\e[0m'
_red_bg() { echo -e "\e[41m$@${none}"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() { echo -e "\n$is_err $@\n" && exit 1; }
warn() { echo -e "\n$is_warn $@\n"; }

[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"

cmd=$(type -P apt-get || type -P yum || type -P zypper || type -P apk)
[[ ! $cmd ]] && err "仅支持主流 Linux 发行版."

is_systemd=$(type -P systemctl)
[[ ! $is_systemd ]] && err "此系统缺少 systemd."

case $(uname -m) in
amd64 | x86_64) is_arch=amd64 ;;
*aarch64* | *armv8*) is_arch=arm64 ;;
*) err "仅支持 64 位系统..." ;;
esac

is_core=sing-box
is_core_name=sing-box
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_core_repo=SagerNet/$is_core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh
is_sh_repo=$author/$is_core
is_pkg="wget tar bash"
[[ $cmd =~ apk ]] && is_pkg="$is_pkg gcompat jq"

tmpdir=$(mktemp -u) || tmpdir=/tmp/tmp-$RANDOM
mkdir -p $tmpdir

_wget() {
    wget --no-check-certificate $*
}

msg() {
    case $1 in
    warn) local color=$yellow ;;
    err) local color=$red ;;
    ok) local color=$green ;;
    esac
    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# 极致 64M 内存 + 1GB 硬盘优化
optimize_system() {
    msg warn "配置 512M Swap 及清理磁盘空间..."
    
    # 1. 挂载 Swap 防止 OOM
    if [[ $(free -m | awk '/Swap:/ {print $2}') -eq 0 ]]; then
        fallocate -l 512M /swapfile &>/dev/null
        chmod 600 /swapfile
        mkswap /swapfile &>/dev/null
        swapon /swapfile &>/dev/null
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    sysctl -w vm.swappiness=60 &>/dev/null

    # 2. 清理系统包管理器缓存以节省 1GB 磁盘
    if [[ $cmd =~ apt-get ]]; then
        apt-get clean &>/dev/null
        apt-get autoremove -y &>/dev/null
    elif [[ $cmd =~ yum ]]; then
        yum clean all &>/dev/null
    elif [[ $cmd =~ apk ]]; then
        apk cache clean &>/dev/null
    fi
}

# 安装精简依赖
install_pkg() {
    msg warn "安装必要依赖..."
    if [[ $cmd =~ apk ]]; then
        apk update &>/dev/null
        apk add $pkg &>/dev/null
    else
        $cmd update -y &>/dev/null
        $cmd install -y $pkg &>/dev/null
    fi
}

# 下载核心文件
download_files() {
    is_core_ver=$(_wget -qO- "https://api.github.com/repos/${is_core_repo}/releases/latest" | grep tag_name | grep -E -o 'v([0-9.]+)')
    [[ ! $is_core_ver ]] && is_core_ver="v1.8.13" # 兜底版本
    
    core_link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-${is_core_ver:1}-linux-${is_arch}.tar.gz"
    sh_link="https://github.com/${is_sh_repo}/releases/latest/download/code.tar.gz"
    jq_link="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_arch"

    msg warn "下载核心与脚本..."
    _wget -q $core_link -O $tmpdir/core.tar.gz
    _wget -q $sh_link -O $tmpdir/sh.tar.gz
    [[ ! $(type -P jq) ]] && _wget -q $jq_link -O /usr/bin/jq && chmod +x /usr/bin/jq
}

# 优化 Systemd 服务文件：极限压榨内存
optimize_systemd_service() {
    local service_file="/etc/systemd/system/$is_core.service"
    if [[ -f $service_file ]]; then
        # 写入极严苛的内存限制和垃圾回收参数
        sed -i '/\[Service\]/a Environment="GOMEMLIMIT=24MiB"\nEnvironment="GOGC=15"\nMemoryMax=36M\nMemoryHigh=30M\nStandardOutput=null\nStandardError=null' "$service_file"
        systemctl daemon-reload
    fi
}

main() {
    clear
    echo "........... sing-box 64M/1G 极限精简版 .........."
    
    optimize_system
    install_pkg
    download_files

    mkdir -p $is_core_dir/bin $is_sh_dir $is_conf_dir $is_log_dir

    tar zxf $tmpdir/core.tar.gz --strip-components 1 -C $is_core_dir/bin
    tar zxf $tmpdir/sh.tar.gz -C $is_sh_dir

    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin
    chmod +x $is_core_bin $is_sh_bin

    echo "alias sb=$is_sh_bin" >>/root/.bashrc

    load systemd.sh
    install_service $is_core &>/dev/null

    # 默认调用最省资源的 Shadowsocks 协议
    load core.sh
    if type -t add_shadowsocks &>/dev/null; then
        add_shadowsocks
    else
        add shadowsocks
    fi

    # 注入极限内存限制及完全关闭日志写入磁盘
    optimize_systemd_service

    # 清理所有临时文件，释放 1GB 盘空间
    rm -rf $tmpdir
    
    # 再次清理系统垃圾
    if [[ $cmd =~ apt-get ]]; then apt-get clean &>/dev/null; fi

    msg ok "安装完成！内存与硬盘已极限优化。"
    exit 0
}

main $@
