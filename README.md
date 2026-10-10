# .emacs.d

个人 Emacs 配置（Emacs Lisp），模块化、跨平台（Windows / Linux / macOS）。
以 evil 为核心，配 vertico/consult/corfu 补全栈、eglot、内置 VC、自维护主题等。

## 结构

- 顶层 **`init.el`**：声明包列表（`use-package … :ensure t :defer t`）+ `require` 各模块。
- **`user-lisp/`**：功能模块（含 `evil-plugins`/`gcmh`/`mode-line`/`tab-line`/`eshell-prompt` 子目录），
  由 Emacs 31 的 **user-lisp 机制**在启动时自动加入 load-path、按需字节编译、生成 autoload；
  `init.el` 直接 `require` 即可。
- **`user-lisp/evil-plugins/`**：evil 插件合集——`evil-surround`/`evil-commentary`/`evil-visualstar`
  已**内联**（不再从 elpa 安装），连同 `evil-config`/`evil-keymaps`/`mc-evil`/`ime` 等自维护模块；
  `user-lisp/gcmh/` 同理内联了 `gcmh`。

```sh
emacs                 # 启动
```

## 常用命令

| 命令 | 作用 |
|------|------|
| `python scripts/bench-startup.py` | 测本机启动速度（详见基准文档） |

## 文档

- **[AGENTS.md](AGENTS.md)** — AI 协作规范、构建/运行/开发流程的**单一事实源**，先读这个。
- **[.agent/](.agent/)** — 与 agent 无关的通用流程文档（`run.md` 批处理验证、`bench.md` 测速）。
- **[docs/startup-benchmark.md](docs/startup-benchmark.md)** — 多机启动速度基准记录与测法。
- **[docs/notes.md](docs/notes.md)** — 配置笔记索引（启动调优、字节编译、安装等）。
