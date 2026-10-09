# 启动速度基准

测量**本机** Emacs 启动速度并生成基准文档，便于排查「同一套配置不同机器启动快慢差很多」。
脚本 `scripts/bench-startup.py`（跨平台 Windows/Linux/macOS），记录写入 `docs/startup-benchmark.md`。

## 用法

```powershell
python scripts/bench-startup.py -a        # 生成记录块并追加到 docs/startup-benchmark.md
```

不加 `-a` 只打印不写文件；`-n 8` 改每场景次数（默认 6）；`--emacs <path>` 指定 emacs。
约 6 次 GUI 启动（~30–60 秒，会弹 Emacs 窗口）。

## 输出

脚本对**全量 profile** 跑 N 次，去首次预热取 **min / 中位数**，并打印机器信息块。

- 每次启动都校验 `(featurep 'evil)`，非 ok 视为 init 没正常加载，该样本作废。
- 记录里 **优先看**：`native-comp` 是否可用、磁盘 **SSD/HDD**、Emacs 版本/来源。

## 注意

- 必须**真实 GUI** 测量，脚本已如此；`--batch` 测不到 GUI 开销。
- 脚本用 `--init-directory` 钉定仓库目录，避免不同 shell/平台把 `~/.emacs.d` 解析到别处。
- 启动调优笔记见 [../docs/notes/startup-performance.md](../docs/notes/startup-performance.md)。
