# 配置笔记 — 索引

渐进式上下文：每条一行 `- [标题](notes/slug.md) — 何时该读`，描述即"要不要展开读"的路由信号。
**维护纪律**：新增笔记 = 在 `notes/` 加一篇 + 在此补一行。

- [Emacs 安装（msys2 UCRT64 + 自编 Emacs 31）](notes/emacs-install-msys2.md) — 装/升级 emacs、构建环境、`make install` 报错、`--batch` 没输出、PATH 上的 emacs 不对时读
- [字节编译与 .elc（user-lisp 自动编译，宏需顶层 require）](notes/byte-compile-broken-elc.md) — 改完/新增模块、用到某个包的宏、报 `Invalid function: …` 或加载坏 `.elc` 时读
- [包源镜像与首次安装](notes/package-mirrors-and-first-install.md) — 换镜像、初次装包失败、签名/缺依赖时读
- [启动性能：测了什么、延迟了什么](notes/startup-performance.md) — 想提启动速度、想知道某项为何延迟/为何不 eager（magit/dired/eglot 首次用时）时读
- [eglot / LSP 手感调优（含若干默认失效的坑）](notes/lsp-eglot-tuning.md) — 调 LSP 跳转/日志/事件缓冲、tree-sitter 模式路由、e2e 某功能却"没反应"时读
- [AI 补全（minuet + SiliconFlow）](notes/ai-completion-minuet.md) — 启用/调试 `init-ai.el`、配 API key 时读
- [Vendor 字体：assets/fonts/](notes/vendored-fonts.md) — mode-line/tab-line 图标乱码、换新机器要装字体、想知道为什么某字体没进仓库、要更新 vendor 字体时读
