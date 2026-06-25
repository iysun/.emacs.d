# .emacs.d

个人 Emacs 配置（Emacs Lisp），模块化、跨平台（Windows / Linux / macOS）。
以 evil 为核心，配 vertico/consult/corfu 补全栈、eglot、magit、doom 主题等。

## 两套 profile

- **全量（默认）**：`init.el` 加载 `lisp/init-*.el` 各模块（evil、补全、UI、LSP、magit…）。
- **精简（minimal）**：单文件 `init-minimal.el`，只含 evil + 内置 project/eglot + completion-preview。

```sh
emacs                 # 全量
emacs --minimal       # 精简（或设环境变量 EMACS_MINIMAL=1）
```

## 启动加速

可选生成自定义 portable dump（`emacs.pdmp`）预加载重包，用 `--dump-file` 内存映射回来省掉
`require` 的几秒。装/删包或升级 Emacs 后需 `make dump` 重建。

## 常用命令

| 命令 | 作用 |
|------|------|
| `make dump` | 生成 `emacs.pdmp` 启动加速映像 |
| `python scripts/bench-startup.py` | 测本机启动速度（详见基准文档） |

## 文档

- **[AGENTS.md](AGENTS.md)** — AI 协作规范、构建/运行/开发流程的**单一事实源**，先读这个。
- **[docs/startup-benchmark.md](docs/startup-benchmark.md)** — 多机启动速度基准记录与测法。
- **[docs/notes.md](docs/notes.md)** — 配置笔记索引（启动调优、字节编译、pdump 等）。
