
# 🚀 Sing-Box 64M 内存 极限优化版

> 基于 [233boy/sing-box](https://github.com/233boy/sing-box) 项目进行深度定制与精简，专为**极低配置 VPS（64MB 内存 / 1GB 硬盘）**打造的轻量化科学上网部署方案。

---

## ✨ 核心优化与特性

在超低配（Micro/Nano）小鸡上，内存溢出（OOM）和磁盘爆满是两大痛点。本版本针对这些问题做了全方位改造：

* 🛠️ **智能 Swap 挂载**：自动检测并创建 `512MB` 虚拟内存（Swap），从根本上杜绝物理内存耗尽导致的 `Killed`（OOM Killer）报错。
* 💾 **1GB 硬盘防爆优化**：
* 安装前后自动清理 `apt` / `apk` 等包管理器缓存。
* 在 Systemd 服务中彻底关闭日志落盘（`StandardOutput=null` / `StandardError=null`），防止日志无限膨胀撑满 1GB 硬盘。


* ⚡ **极限内存压榨（Go 运行时调优）**：
* 注入环境变量 `GOMEMLIMIT=24MiB` 与 `GOGC=15`，强制 Go 语言垃圾回收器更激进地释放内存。
* 设置 Systemd 硬件内存硬限制 (`MemoryMax=36M`)，将常驻内存死死压制在 20MB~30MB 左右。


* 🚀 **协议降级防爆**：放弃相对吃资源的复杂协议（如 Reality/Hysteria2），默认启用对内存和 CPU 要求最低的 **Shadowsocks** 协议。

---

## 📥 一键安装命令

使用以下命令直接开始安装（请将链接替换为你自己的脚本托管地址，或直接运行你优化后的 `install.sh`）：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/你的用户名/仓库名/main/install.sh)

```

---

## ⚙️ 常用管理命令

安装成功后，你可以直接使用简化命令进行管理：

* **管理面板/主菜单**：输入 `sb` 或 `sing-box` 调出交互菜单。
* **查看运行状态**：`systemctl status sing-box`
* **重启服务**：`systemctl restart sing-box`

---

## ⚠️ 64M 极小内存使用须知

1. **切勿开启面板/统计**：请勿在客户端或服务端开启复杂的流量统计、Web Dashboard 等常驻内存功能。
2. **定位为备用节点**：该配置仅适合作为轻量科学上网、日常网页浏览或备用应急节点，**严禁**用于高速 BT 下载或长时间观看 4K 视频。
3. **监控系统状态**：建议安装完成后使用 `free -m` 和 `df -h` 观察内存与硬盘占用情况。

---

### 💡 致谢

* 原作者：[233boy](https://github.com/233boy/sing-box)
* 核心程序：[SagerNet/sing-box](https://github.com/SagerNet/sing-box)
