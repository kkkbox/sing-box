#!/bin/bash

author=233boy

# bash fonts colors
red='\e[31m'
yellow='\e[33m'
green='\e[92m'
blue='\e[94m'
cyan='\e[96m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
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
is_config_json=$is_core_dir/config.json

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

load() {
    . $is_sh_dir/src/$1
}

# 极致 64M 内存 + 1GB 硬盘优化
optimize_system() {
    msg warn "配置 512M Swap 及清理磁盘空间..."
    
    if [[ $(free -m | awk '/Swap:/ {print $2}') -eq 0 ]]; then
        fallocate -l 512M /swapfile &>/dev/null
        chmod 600 /swapfile
        mkswap /swapfile &>/dev/null
        swapon /swapfile &>/dev/null
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    sysctl -w vm.swappiness=60 &>/dev/null

    if [[ $cmd =~ apt-get ]]; then
        apt-get clean &>/dev/null
        apt-get autoremove -y &>/dev/null
    elif [[ $cmd =~ yum ]]; then
        yum clean all &>/dev/null
    elif [[ $cmd =~ apk ]]; then
        apk cache clean &>/dev/null
    fi
}

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

download_files() {
    is_core_ver=$(_wget -qO- "https://api.github.com/repos/${is_core_repo}/releases/latest" | grep tag_name | grep -E -o 'v([0-9.]+)')
    [[ ! $is_core_ver ]] && is_core_ver="v1.8.13"
    
    core_link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-${is_core_ver:1}-linux-${is_arch}.tar.gz"
    sh_link="https://github.com/${is_sh_repo}/releases/latest/download/code.tar.gz"
    jq_link="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_arch"

    msg warn "下载核心与脚本..."
    _wget -q $core_link -O $tmpdir/core.tar.gz
    _wget -q $sh_link -O $tmpdir/sh.tar.gz
    [[ ! $(type -P jq) ]] && _wget -q $jq_link -O /usr/bin/jq && chmod +x /usr/bin/jq
}

optimize_systemd_service() {
    local service_file="/etc/systemd/system/$is_core.service"
    if [[ -f $service_file ]]; then
        # 写入极严苛的内存限制，关闭标准输出防止写爆 1GB 硬盘
        sed -i '/\[Service\]/a Environment="GOMEMLIMIT=24MiB"\nEnvironment="GOGC=15"\nMemoryMax=36M\nMemoryHigh=30M\nStandardOutput=null\nStandardError=null' "$service_file"
        systemctl daemon-reload
        systemctl restart $is_core
    fi
}

main() {
    clear
    echo "........... sing-box 64M/1G 极致精简版 (VLESS-Reality) .........."
    
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
    is_new_install=1
    install_service $is_core &>/dev/null

    mkdir -p $is_conf_dir

    # 加载 core.sh 并默认生成 VLESS-Reality 协议
    load core.sh
    add reality

    optimize_systemd_service

    rm -rf $tmpdir
    if [[ $cmd =~ apt-get ]]; then apt-get clean &>/dev/null; fi

    msg ok "安装完成！已默认配置 VLESS-Reality，内存与硬盘已优化。"
    exit 0
}

main $@
