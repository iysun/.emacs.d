# 字节编译与 .elc（曾产坏字节码，已修复）

## 曾经的现象

`make compile` 或单独 `batch-byte-compile` 之后，从 `.elc` 启动全量 profile 报：

```
Symbol's value as variable is void: evil-a-between
Invalid function: evil-define-key
```

## 根因（已实测确认）

`evil-define-text-object` 与 `evil-define-key` 都是**宏**（已用 `macrop` 验证）。
本配置在**顶层**用了它们（`init-evil.el` / `init-keymaps.el`）。

- **加载源码 `.el`**：`init-evil.el` 的 `(evil-mode 1)` 先加载 evil，宏可用 → 正常。
- **字节编译**：byte-compiler **不会**执行 `(evil-mode 1)`（它只执行 `require` /
  `eval-when-compile` 等少数顶层形式），编译期 evil 未加载，宏不可见 → 编译器把宏调用当**函数**编译，
  `evil-a-between` 被当变量、`evil-define-key` 被当函数 → 产出坏 `.elc`。
  而 Emacs 启动优先加载 `.elc`，于是从 `.elc` 启动即崩。
- 雪上加霜：`init-keymaps.el` 原本有 `(declare-function evil-define-key "evil" …)`，
  **把宏显式声明成函数**，正好坐实了错误编译。

## 修复（已实施）

在用到 evil 宏的模块**顶层**加 `(require 'evil)`（byte-compiler 会执行顶层 `require`，
使宏在编译期可用；源码加载时也保证宏先于使用处可用）：

- `lisp/init-evil.el` 顶层 `(require 'evil)`。
- `lisp/init-keymaps.el`：删掉误导的 `declare-function`，改为顶层 `(require 'evil)`。
- `lisp/init-evil-plugins.el`（停用）：同样顶层 `(require 'evil)`。

验证：`make compile` 产出的 `.elc` 现可正常加载；全量 + 精简两套 profile 在 `--batch` 下均干净加载。

## 仍要记住

- 本仓库约定加载 `.el` 源码（`.elc` 已 gitignore）。
- 交互会话 `load-prefer-newer` 为 nil（见 `early-init.el`），**残留旧 `.elc` 会盖过更新的 `.el`**。
  所以编译只用于检查；检查完清掉自己的 `.elc`（`make clean` 在 Windows 因 GNU find 失效，改用）：
  ```powershell
  Get-ChildItem -Path .,lisp -Filter *.elc -File | Remove-Item -Force
  ```
  `/build` 命令已内置「编译→清理」。
- 若日后再加用到某包顶层宏的模块，记得在该模块顶层 `(require '那个包)`，避免重蹈覆辙。
