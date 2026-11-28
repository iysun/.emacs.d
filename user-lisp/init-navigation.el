;; -*- lexical-binding: t; -*-
;; 跳转 / 符号 / tags 补全都走 eglot → lspmux，不再加载 citre。
;; 跳转入口是 xref（`gd` / `M-.`）。tags 索引：Emacs 项目自动，否则 SPC c。

(provide 'init-navigation)
