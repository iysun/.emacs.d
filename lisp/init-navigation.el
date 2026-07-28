;; init-navigation.el 	-*- lexical-binding: t -*-
;;
;; citre（ctags/readtags 兜底导航）+ imenu-list（大纲侧栏）。补 eglot/xref 覆盖不到
;; 的场景：没有 LSP 的第三方代码、vendored 库。

(require 'imenu-list)
(global-set-key (kbd "C-'") 'imenu-list-smart-toggle)

;; citre 需要外部 Universal Ctags（ctags/readtags）。本机没装就连包都不装，
;; 同 init-full.el 里 fd-dired 的条件式写法。
(when (executable-find "readtags")
  (use-package citre :ensure t :defer t)
  (require 'citre)
  (setq citre-auto-enable-citre-mode nil)  ; 不用 citre 自带的自动挂载逻辑，改用下面的 hook 手动挂
  (add-hook 'prog-mode-hook #'citre-mode)
  (with-eval-after-load 'citre
    (define-key citre-mode-map (kbd "<f12>")   'citre-jump)
    (define-key citre-mode-map (kbd "S-<f12>") 'citre-jump-to-reference)
    (define-key citre-mode-map (kbd "M-<f12>") 'citre-peek)))

(provide 'init-navigation)
