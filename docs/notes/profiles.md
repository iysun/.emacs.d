# 两套 profile：全量与精简

`init.el` 是 profile 分发器。命中 `--minimal` 命令行参数或 `EMACS_MINIMAL` 环境变量即走精简，否则全量。

## 精简（minimal）

- 单文件 `init-minimal.el`（与 `init.el` 同级，按路径 `load`，不走 `load-path`）。
- 内容：evil + 内置 project/eglot + completion-preview，轻量。
- 启动：`emacs --minimal` 或 `EMACS_MINIMAL=1 emacs`。
- 批处理可干净加载，可作冒烟门禁（见 `/run` A 部分）。

## 全量（full，默认）

- `init.el` 声明包列表（`use-package … :ensure t :defer t`），再 `require` 各 `lisp/init-*.el` 模块。
- 当前启用：`init-base` `init-evil` `init-ui` `init-window` `init-completion` `init-dired`
  `init-git` `init-term` `init-project` `init-mc` `init-keymaps` `init-lsp`。
- `init-ai` / `init-evil-plugins` / `lang-go` 已写好但在 `init.el` 末尾注释停用。

## 实现细节

`--minimal` 不是 Emacs 内置参数，`init.el` 在 `command-line-1` 处理剩余参数**之前**手动把它从
`command-line-args` 删掉，否则启动末尾会报 "Unknown option"。

## 注意

修复 evil 宏的编译脆弱点后（见 [byte-compile-broken-elc](byte-compile-broken-elc.md)），
全量与精简两套 profile 都能在 `--batch` 下干净加载，`/run` 即验证这两步。
批处理只验证「能否无错加载」，视觉外观仍需启动真实 Emacs 确认。
