---
name: build
description: 生成自定义 portable dump（emacs.pdmp）加速启动；预加载某包失败则从 dump.el 列表剔除后重建
---

构建本配置的**自定义 portable dump**（`emacs.pdmp`）：把启动期/常用重包预加载进映像，
启动时用 `--dump-file` 内存映射回来，省掉 `require` 的几秒。脚本是 `dump.el`。

> 用映像启动：`emacs --dump-file=<.emacs.d>/emacs.pdmp`，或用仓库根的 `emacs-dump.cmd`。
> ⚠️ 装/删包或升级 emacs（scoop 更新）后**必须重跑本命令**，否则映像不兼容、启动报错。

## 循环

1. **构建**：
   ```powershell
   make dump            # 等价：emacs --batch -Q -l dump.el
   ```

2. **读输出，按情况处理**：
   - 正常：末尾 `dump: 预加载 N 个包，跳过 0 个` + 生成 `emacs.pdmp`（约 ~48MB）。
   - **某包 require 失败**：输出里有 `dump: 跳过 <pkg> (...)`——该包没烤进映像（不致命，运行时再正常加载）。
     若该包本应预加载，检查它是否已装（`elpa/`）。
   - **`dumping overlays is not yet implemented`**：某包加载时建了 overlay。`dump.el` 已在转储前
     `remove-overlays` 兜底；若仍报，定位是哪个包建的 overlay，必要时把它从 `dump.el` 的预加载集移除。
   - **转储期其它报错**：通常是某包加载了不可转储的状态。把嫌疑包（优先 `dump.el` 里「加分组」的
     magit / eat 等）从预加载集删掉，重跑，直到成功产出 `emacs.pdmp`。

3. **校验映像可用 + 配置完整**（关键——`emacs-init-time` 极小常意味着 init 中途崩了，不是真快）：
   ```powershell
   emacs --batch --dump-file="$PWD\emacs.pdmp" --eval "(message `"evil:%s`" (featurep 'evil))"
   # 应打印 evil:t、退出码 0（映像兼容）
   ```
   更完整的功能/加载验证用 **`/run`** 思路：带 `--dump-file` 启动真实 Emacs，确认所有 `init-*` 模块
   都 `featurep`、`*Warnings*` 为空、evil-mode 开、主题/tab-line/modeline 正常。

## 注意

- **不要在 `dump.el` 里跑用户 init**：dump 期无 GUI，跑 init 会踩字体/frame/主题坑。只预加载第三方库。
- `dump.el` 末尾会复位 `package--initialized` / `package-activated-list` / `package-alist`，
  让启动时 `init.el` 的 `package-initialize` 重建 load-path（否则没烤进映像的包如 fd-dired 会找不到）。
- evil 必须在 `dump.el` 里先设 `evil-want-keybinding nil` 再 require，否则启动报 evil-collection #60。
- 本命令**不校验用户 config 语法**（dump 只加载第三方库）。config 正确性用 `/run`；纯语法 lint 用 `make compile`
  （注意它产 `.elc`，检查完用 PowerShell 清掉：`Get-ChildItem -Path .,lisp -Filter *.elc -File | Remove-Item -Force`）。
- `emacs.pdmp` 已 gitignore，勿提交。
