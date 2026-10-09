# 启动性能基准（多机对比）

记录各台电脑上的 Emacs 启动速度，用于排查「同一套配置不同机器启动快慢差很多」的问题。
配置/开发流程见 [AGENTS.md](../AGENTS.md)；启动调优笔记见 [docs/notes/startup-performance.md](notes/startup-performance.md)。

## 怎么测

跨平台脚本，Windows / Linux / macOS 通用：

```sh
python scripts/bench-startup.py        # 打印一段「机器记录块」到屏幕
python scripts/bench-startup.py -a     # 直接把记录块追加到本文件「机器记录」区
python scripts/bench-startup.py -n 8   # 跑 8 次（默认 6）
```

脚本自动：采集机器信息（CPU/内存/磁盘/OS/Emacs 版本/native-comp）+ 对**全量 profile** 跑 N 次
**真实 GUI** `emacs-init-time`，输出可粘贴的 Markdown 块。

## 指标与排查要点

- 跑 N 次，**去掉第一次预热**，取 **min / 中位数**（Windows/磁盘缓存噪音大，**min 最具参考性**）。
- 每次启动校验 `(featurep 'evil)`（全量会加载 evil）；非 ok 视为 init 没正常加载，该样本作废。
- ⚠️ 必须**真实 GUI** 测量，`--batch` 测不到 GUI 开销；脚本用 `--init-directory` 把配置目录钉到本仓库
  （否则不同 shell/平台下 `~/.emacs.d` 可能解析到别处）。细节见 [docs/notes/startup-performance.md](notes/startup-performance.md)。
- **两机差异优先看这几个字段**：`native-comp` 是否可用、磁盘 **SSD/HDD**、Emacs 版本/来源。

## 机器记录

<!-- 在此区粘贴 scripts/bench-startup.py 的输出块；或用 `-a` 自动追加 -->

> ⚠️ 以下为**旧格式记录**（2026-06-25，Emacs 30.2，脚本当时还测「dump 映像 / 全量 / 精简 minimal」
> 三种场景，含 `emacs.pdmp` 字段）。这些场景已随配置简化移除，数据仅供参考，**需重跑 `python scripts/bench-startup.py` 刷新**。

### PC-20241114VUMP（2026-06-25）

| 字段 | 值 |
|---|---|
| OS | Windows 10 (10.0.19045) |
| CPU | Intel(R) Core(TM) i5-10210U CPU @ 1.60GHz（8 逻辑核） |
| 内存 | 15.8 GB |
| 磁盘 | SSD |
| Emacs | GNU Emacs 30.2 |
| native-comp | ❌ 不可用 |

| 场景 | min(s) | 中位数(s) | 有效/总次数 |
|---|---|---|---|
| 普通全量 | 3.034 | 3.548 | 5/6 |

### ballentin（2026-06-25）

| 字段 | 值 |
|---|---|
| OS | Windows 11 (10.0.22631) |
| CPU | AMD Ryzen 7 7840H with Radeon 780M Graphics（16 逻辑核） |
| 内存 | 27.7 GB |
| 磁盘 | SSD |
| Emacs | GNU Emacs 30.2 |
| native-comp | ❌ 不可用 |

| 场景 | min(s) | 中位数(s) | 有效/总次数 |
|---|---|---|---|
| 普通全量 | 6.605 | 6.669 | 5/6 |
