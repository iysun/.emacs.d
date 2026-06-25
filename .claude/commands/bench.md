---
name: bench
description: 测本机 Emacs 启动速度（dump/全量/精简三场景真实 GUI），结果追加到 docs/startup-benchmark.md，用于多机对比
---

测量**本机** Emacs 启动速度并记入基准文档，用于排查「同一套配置不同机器启动快慢差很多」。
脚本 `scripts/bench-startup.py`（跨平台 Windows/Linux/macOS），记录写入 `docs/startup-benchmark.md`。

## 跑

```powershell
python scripts/bench-startup.py -a        # 测三场景并追加机器记录块到 docs/startup-benchmark.md
```

不带 `-a` 只打印不写文件；`-n 8` 改每场景次数（默认 6）；`--emacs <path>` 指定 emacs。
约 18 次 GUI 启动、~1–2 分钟，过程会闪 Emacs 窗口（建帧后自杀），属正常。

## 读输出

脚本对三场景各跑 N 次，去首次预热取 **min / 中位数**，并打印机器信息块：

- **dump 映像**：`--dump-file=emacs.pdmp`（日常用法；pdmp 缺失会标「跳过」——先跑 `/build`）。
- **普通全量** / **精简 minimal**（`EMACS_MINIMAL=1`）。
- 每行末「有效/总次数」：脚本每次启动校验 `(featurep 'evil)`，非 ok 的样本作废。
  若某场景 `0/N`（全部无效）→ init 没正常加载，去看 `*Warnings*`（多半 pdmp 不兼容或缺包）。

## 多机对比要点

记录里 **优先看**：`native-comp` 是否可用、磁盘 **SSD/HDD**、`emacs.pdmp` 是否存在且与当前 Emacs 匹配、
Emacs 版本/来源。两台机「同配置不同速度」基本由这几项解释。在另一台机 clone 后跑同一命令即可同口径追加。

## 注意

- 必须**真实 GUI** 测量（脚本如此做）；`--batch` 测不到 GUI 开销，别用 batch 数当启动速度。
- 脚本已用 `--init-directory` 把配置目录钉到本仓库——**勿删**：否则不同 shell/平台下 `~/.emacs.d`
  可能解析到别处（Windows 上 HOME 与 %APPDATA% 不一致会加载空配置，测出假性「超快」）。
- 只测速、**不改配置**；调优思路见 [docs/notes/startup-performance.md](../../docs/notes/startup-performance.md)。
