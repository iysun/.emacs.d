# 启动性能：测了什么、延迟了什么

实测真实 GUI `M-x emacs-init-time`：**7.5s → 5.9s**（配套 `--batch` 加载约 6s）。Windows + Defender 噪音较大。

⚠️ **关键教训：`--batch` 测不到纯 GUI 开销**（字体、主题、modeline、**centaur-tabs** 都需 display）。
所以 batch 显示 ~6s 但真实 GUI 曾 7.5s——差值几乎全是 centaur-tabs。**调启动一定要用真实 GUI 的
`emacs-init-time` 复核，别只信 batch。** 见下方实测分项。

## GUI 分项实测（`emacs -Q` 单帧逐项计时）

| 操作 | GUI 耗时 | 处置 |
|------|---------|------|
| **centaur-tabs（require + 全局 mode）** | **~2.2s** | **已移除**：换内置 `tab-line`（项目分组 + 过滤 eglot buffer），见 `init-window.el` |
| `require evil` | 0.53s | 必需 |
| `package-initialize` | 0.41s | 必需 |
| `require nerd-icons` | 0.36s | 仍用于 corfu/dired/completion（modeline/tabs 不再用） |
| doom-modeline（require+mode） | 0.28s + 启动加载 | **已移除**：换手写 `mode-line-format`，见 `init-ui.el` |
| `load-theme doom-one` | 0.10s | 廉价 |
| `font-family-list` ×5 | 0.04s | **不是问题**（曾担心 Windows 字体枚举慢，实测廉价） |

### centaur-tabs 为何曾在启动加载（已修）
`init-window.el` 的 `(popper-mode +1)` → `popper-mode-hook` → `centaur-tabs-local-mode`（autoload）→ 拉起 centaur-tabs。
修法：把那两个 `centaur-tabs-local-mode` 钩子移进 `(with-eval-after-load 'centaur-tabs …)`，再用
`emacs-startup-hook` + `run-with-idle-timer 0.3` 显式延迟 require。frame 先出来、标签栏 ~瞬间补上，
`emacs-init-time` 不再含这 2.2s。代价：启动后约 0.3s 才出标签栏。

## 实测开销（相对基线）

| 项 | 开销 | 处置 |
|----|------|------|
| dired 四件套（quick-sort/git-info/rsync/subtree） | ~1.6s | 延迟：`init-dired.el` 整体包进 `(with-eval-after-load 'dired …)` |
| `eglot` 裸 require | ~1.1s | 删除 eager require；靠 `*-ts-mode-hook` 上的 `eglot-ensure` 按需加载 |
| dashboard 首屏 | ~0.3s + 渲染 | 禁用（`init-ui.el` 注释掉 `dashboard-setup-startup-hook`；`early-init.el` 开 `inhibit-startup-screen`） |
| `exec-path-from-shell` 裸 require | 小 | 删除（`-initialize` 本就注释，空载） |
| `evil-collection-init`（无参） | ~0.18s | **保持**——现代版按 mode 延迟，并不慢（曾被误判为大头） |
| `treesit-auto` 裸 require | ~0 | **保持**——在基线噪音内 |
| corfu/vertico/consult/embark/cape… | 合计 ~0.4s | **保持**——多在 `after-init-hook` |
| `magit` | require 要 ~4.6s | **不在启动路径**（`init-git.el` 用 `with-eval-after-load 'magit`）；首次 `M-x magit` 才付这笔 |

## 没采用的：package-quickstart

试过 `(setq package-quickstart t)` + 预生成 `package-quickstart.el`。实测只快 ~100ms，
因为 `init.el` 显式调 `(package-initialize)`（它**不走** quickstart；只有 `package-activate-all` 才用）。
为 ~100ms 改 init.el 又得每次装/删包重新生成 311KB 文件，不值——**已回退**。

## after-init-hook 分项（`emacs -Q` 逐项计时）

| 项 | 耗时 | 处置 |
|----|------|------|
| **global-diff-hl-mode** | **~0.40s** | **延迟**：从 after-init 挪到首次 `find-file` 一次性启用（`init-git.el`） |
| use-emacs-theme（load-theme doom-one） | 0.24s | 必需 |
| vertico-mode | 0.12s | 必需（首个 minibuffer 命令要用） |
| recentf-mode | 0.11s | 保持 |
| global-corfu-mode / marginalia / winner / savehist | 各 <0.04s | 保持 |

## 走到头的与不能动的

- **native-comp 不可用**：本机 emacs（scoop）`(native-comp-available-p)` => nil，0 个 `.eln`。
  包只能跑字节码——`require evil`(~0.5s)、doom-modeline+nerd-icons(~0.67s) 是**硬地板**，
  没法靠原生编译再压。`early-init.el` 里 `native-comp-jit-compilation nil` 在本机是空操作。
- **Windows Defender 不是瓶颈**：`Get-MpPreference` 显示 `C:\` 和 `D:\` 整盘已被排除（Sangfor 安全软件设的），
  即 `.emacs.d` / `scoop` 本就不被实时扫描。加目录排除是冗余，实测几乎无变化。
- **剩余 ~5.3s 里约 2s 是真实 GUI 开销**：建帧 + `toggle-frame-maximized` 最大化重绘 +
  主题/相对行号/ligature/modeline 在大帧上的 redisplay + 加载 custom.el。配置层很难再削，
  除非牺牲可见特性（行号、主题、连字…）。

## 真想更快：用 daemon + emacsclient

per-launch ~5.3s 已接近本机这套配置的地板。日常体感要「秒开」，正解是
**`emacs --daemon` 跑一个常驻进程**（开机/后台付一次 ~5.3s），之后用
`emacsclientw.exe -c -a runemacs` 开窗口——**瞬开**。这是重配置 Emacs 的标准做法。

## 权衡与验证

- 代价：首次打开 dired / 首个代码文件会各多付一次对应加载（dired 包 / eglot）——属预期。
- 验证：`/run` 确认两套 profile `EXIT=0`；`emacs` 启动后 `M-x emacs-init-time` 看实际耗时；
  确认 dired 键位（S/I/TAB/C-c C-r）、`.go`/`.c` 文件 eglot 正常起、主题/modeline 正常、无 dashboard 首屏。
- 想看启动耗时可加：`(add-hook 'emacs-startup-hook (lambda () (message "ready in %s" (emacs-init-time))))`。
