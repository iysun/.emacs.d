;; -*- lexical-binding: t; -*-
;; 定义跳转不走 xref：eglot 的 xref 会在主线程上等到回应。
;; `gd` / `M-.` 在 lspmux-async-mode 里发 lspmux/definition。

(provide 'init-navigation)
