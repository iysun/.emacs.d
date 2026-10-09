# gcmh

内联的 `gcmh`（Garbage Collector Magic Hack），MELPA 2020-11-16，**GPLv3**。

由 user-lisp 机制自动加入 load-path；`lisp/init-base.el`（`user-lisp/init-base.el`）
顶层 `(require 'gcmh)` 使用，启动后动态管理 GC。

不再自动跟进上游更新，升级需手动替换 `gcmh.el`。
