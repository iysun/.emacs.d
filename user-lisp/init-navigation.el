;; init-navigation.el 	-*- lexical-binding: t -*-
;;
;; citre（ctags/readtags 补 eglot/xref 覆盖不到的场景：没有 LSP 的第三方代码、
;; vendored 库）。citre-mode 开着时会把自己的 xref backend（eglot→tags→global
;; 三级兜底，见 citre-find-definition-backends/citre-find-reference-backends）
;; 注册进 buffer-local 的 xref-backend-functions；init-lsp.el 的
;; eglot-managed-mode-hook 把它排到 eglot 裸 backend 前面，所以 gd/M-./M-? 这些
;; 标准 xref 入口本身就有 tags/global 兜底，不用 citre 自己另开一套跳转键。
;; citre 现在只保留一个不可替代的命令：`SPC p'（citre-peek，原地预览定义、不跳转，
;; 见 init-keymaps.el 的 `C-x b'），xref 前端没有等价物。

;; citre 需要外部 Universal Ctags（ctags/readtags）。本机没装就连包都不装，
;; 同 init.el 里 fd-dired 的条件式写法。
(when (executable-find "readtags")
  ;; 不要 eager `(require 'citre)`；citre-mode 有 autoload，挂到 prog-mode-hook，
  ;; 首次打开**文件**时才加载 citre。加 buffer-file-name 守卫：*scratch* 属于
  ;; prog-mode（lisp-interaction-mode），否则启动时就把它拉起来了。
  (use-package citre :ensure t :defer t)
  (add-hook 'prog-mode-hook
            (lambda () (when (buffer-file-name) (citre-mode 1))))
  (with-eval-after-load 'citre
    (setq citre-auto-enable-citre-mode nil)))  ; 用上面的 hook 手动挂，不用 citre 自带逻辑

(provide 'init-navigation)
