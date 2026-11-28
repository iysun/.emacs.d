;; -*- lexical-binding: t; -*-
;; 跳转 / 符号 / tags 补全都走 eglot → lspmux，不再加载 citre。
;; 跳转入口是 xref（`gd` / `M-.`），多条 definition 时出 *xref*。

(provide 'init-navigation)
