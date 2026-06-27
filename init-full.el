;;; init-full.el --- 全量启动配置 -*- lexical-binding: t; -*-
;;
;; 模块化完整配置：evil、补全栈、UI、LSP、magit 等。
;; 由仓库根 `init.el' 在全量 profile 时加载。
;; GC 延迟与 custom-file 由 `early-init.el' / 根 `init.el' 统一处理，此处不再重复。

(require 'package)
(setq package-archives
      '(("gnu"    . "https://mirrors.ustc.edu.cn/elpa/gnu/")
        ("melpa"  . "https://mirrors.ustc.edu.cn/elpa/melpa/")
        ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")
        ("org"    . "https://mirrors.ustc.edu.cn/elpa/org/")))
;;(setq package-archives
;;  '(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
;;    ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
;;    ("melpa"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
(package-initialize)

(require 'use-package)

(dolist (package
         '(evil
           evil-collection
           evil-surround
           evil-visualstar
           evil-commentary
           posframe
           multiple-cursors
           ace-window
           hydra
           rainbow-delimiters
           doom-themes
           popper
           consult
           embark
           embark-consult
           marginalia
           consult-eglot
           eldoc-mouse
           magit
           diff-hl
           dired-quick-sort
           dired-git-info
           dired-rsync
           diredfl
           dired-subtree
           eshell-git-prompt
           eshell-syntax-highlighting
           orderless
           vertico
           corfu
           corfu-terminal
           cape
           eat))
  (eval `(use-package ,package :ensure t :defer t)))

(when (executable-find "fd")
  (use-package fd-dired :ensure t :defer t)
  (require 'fd-dired))

(require 'init-base)
(require 'init-evil)
(require 'init-ui)
(require 'init-window)
(require 'init-completion)
(require 'init-dired)
(require 'init-git)
(require 'init-term)
(require 'init-project)
(require 'init-mc)

(require 'init-keymaps)
(require 'init-lsp)

;;(require 'init-ai)
;;(require 'init-evil-plugins)
;;
;;(require 'lang-go)

(provide 'init-full)

;;; init-full.el ends here
