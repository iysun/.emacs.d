# 启动性能：测了什么、延迟了什么

> **当前结论（2026-11-23，Emacs 31.1 + native-comp 可用）**：
> 真实 GUI `emacs-init-time` **min 0.349s / median 0.356s**
> （`python scripts/bench-startup.py -n 6`，5/6 有效；原始记录见
> [docs/startup-benchmark.md](../startup-benchmark.md)）。
>
> 下面出现的 7.5s / 5.9s / 5.3s / 6s 等数字都是 **2026-06/07 的历史测量**
> （Emacs 30.2、无 native-comp、还带 centaur-tabs / doom-modeline / magit / dashboard）。
> 它们只用于解释“当时为什么慢、为什么删掉某个包”，**不要再当现状引用**。
> 旧文档把 ~5.3s 说成“本机地板”，是没跟上后续删包 + native-comp + quickstart 的漂移；
> 当前 init 已不到 0.4s。

## 历史分项（2026-06，Emacs 30.2，无 native-comp）

| 操作 | GUI 耗时 | 处置 |
|------|---------|------|
| **centaur-tabs（require + 全局 mode）** | **~2.2s** | **已移除**：换内置 `tab-line`（项目分组 + 过滤 eglot buffer），见 `user-lisp/tab-line/init-tab-line.el` |
| `require evil` | 0.53s | 必需 |
| `package-initialize` | 0.41s | 已被 `package-quickstart` + `package-activate-all` 取代 |
| `require nerd-icons` | 0.36s | 仍用于 corfu/dired/completion（modeline/tabs 不再用） |
| doom-modeline（require+mode） | 0.28s + 启动加载 | **已移除**：换手写 `mode-line-format`，见 `user-lisp/mode-line/init-mode-line.el` |
| `load-theme doom-one` | 0.10s | 已换 `catppuccin`（调色板驱动，见 `themes/iys-theme-core.el`） |
| `font-family-list` ×5 | 0.04s | **不是问题**（曾担心 Windows 字体枚举慢，实测廉价） |

### centaur-tabs 为何曾在启动加载（已修）

`init-window.el` 的 `(popper-mode +1)` → `popper-mode-hook` → `centaur-tabs-local-mode`（autoload）→ 拉起 centaur-tabs。
修法：把那两个 `centaur-tabs-local-mode` 钩子移进 `(with-eval-after-load 'centaur-tabs …)`，再用
`emacs-startup-hook` + `run-with-idle-timer 0.3` 显式延迟 require。后来直接整套移除，换内置 tab-line；
这段只作为“为什么当初会慢”的历史记录。

## 历史开销（相对基线）

| 项 | 开销 | 处置 |
|----|------|------|
| ~~dired 四件套（quick-sort/git-info/rsync/subtree）~~ | ~1.6s | **2026-07-28 已移除**：参照 zdn/.emacs.d 改成纯内置 dired/dired-aux/dired-x 实现（`user-lisp/init-dired.el`），四个包全砍 |
| `eglot` 裸 require | ~1.1s | 删除 eager require；靠 `*-ts-mode-hook` 上的 `eglot-ensure` 按需加载 |
| dashboard 首屏 | ~0.3s + 渲染 | **已移除**（仓库不再依赖 dashboard；`early-init.el` 开 `inhibit-startup-screen`） |
| `exec-path-from-shell` 裸 require | 小 | 删除（`-initialize` 本就注释，空载） |
| `evil-collection-init`（无参） | ~0.18s | **保持**——现代版按 mode 延迟，并不慢（曾被误判为大头） |
| `treesit-auto` 裸 require | ~0 | **保持**——在基线噪音内 |
| corfu/vertico/consult/embark/cape… | 合计 ~0.4s | **保持**——多在 `after-init-hook` |
| ~~`magit`~~ | ~~require 要 ~4.6s~~ | **2026-10-10 已移除**：不再使用 magit，git 操作改用内置 VC（`C-x v d`） |

## package-quickstart（已采用）

`early-init.el`：`(setq package-quickstart t)`（快照 `var/package-quickstart.el`）+ `(package-activate-all)`，
**不再**显式 `(package-initialize)`。历史测量：真实 GUI `emacs-init-time` **1.25s → 0.92s（约 −0.33s）**。
现在 init 已 ~0.35s，quickstart 仍是必要项：它把“激活所有包”从每次启动的 load-all-descriptors 变成一份快照，
且用户-lisp 的自动字节编译发生在 init 之前，包必须提前激活。

快照过期**不报错**，由 `init.el` 的 `iys/check-quickstart-freshness` 兜底告警；装/删包走
package.el 会自动重建（`package--quickstart-maybe-refresh`），手工改 `elpa/` 则需 `M-x package-quickstart-refresh`。

## after-init-hook 历史分项

| 项 | 耗时 | 处置 |
|----|------|------|
| ~~global-diff-hl-mode~~ | ~~~0.40s~~ | **已移除**：`init-git.el` 明确不再引入 diff-hl，git 状态走内置 VC |
| iys/use-emacs-theme（load-theme catppuccin） | 0.24s | 必需 |
| vertico-mode | 0.12s | 必需（首个 minibuffer 命令要用） |
| recentf-mode | 0.11s | 保持 |
| global-corfu-mode / marginalia / winner / savehist | 各 <0.04s | 保持 |

## 当前怎么看启动

- **优先看 `emacs-init-time` 的 min/中位数**，用 `python scripts/bench-startup.py -n 6` 复测；
  不要拿旧文档里的 5.3s 当基线。
- `emacs-init-time` **只覆盖 init 阶段**：进程创建、GUI 首帧、首次 redisplay、`toggle-frame-maximized`
  等不在里面。要测“窗口可交互”的端到端时间，得用外部计时（PowerShell `Measure-Command` 包住
  `emacs --init-directory ...` 并让它在 `window-setup-hook` 后退出），别把两者混为一谈。
- 真正的大头如果回来，先看 `*Warnings*` / `*Messages*` 有没有包被意外 eager require；
  再用 `emacs --batch -l early-init.el --eval '(profiler-start ...)'` 或 `benchmark-run` 定位，
  不要先归因于“Windows 就是慢”。

## daemon 还要不要

**init 已经 0.35s，daemon 对“冷启动速度”的收益很小**。它仍适合：
保留 buffer / 撤销历史 / 打开多个 frame；以及 `emacsclient` 快速连到同一进程。
但不要再把“拯救 5.3s”当理由——那是旧配置的数字。

## 权衡与验证

- 代价：首次打开 dired / 首个代码文件会各多付一次对应加载（dired 包 / eglot）——属预期。
- 验证：按 [.agent/run.md](../../.agent/run.md) 批处理加载确认 `EXIT=0`；`emacs` 启动后
  `M-x emacs-init-time` 看实际耗时；`python scripts/bench-startup.py -n 6` 复测 min/中位数。
- 确认 dired 键位（S/I/TAB/C-c C-r）、`.go`/`.c` 文件 eglot 正常起、主题/modeline 正常、无启动首屏。
