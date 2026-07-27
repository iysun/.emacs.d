;;; init-full.el --- 全量启动配置 -*- lexical-binding: t; -*-
;;
;; 模块化完整配置：evil、补全栈、UI、LSP、magit 等。
;; 由仓库根 `init.el' 在全量 profile 时加载。
;; GC 延迟与 custom-file 由 `early-init.el' / 根 `init.el' 统一处理，此处不再重复。

(require 'package)
(require 'init-mirrors)                 ; package-archives 的唯一定义处
(package-initialize)

(require 'use-package)

;; no-littering：把各包的运行期文件收进 var/ 与 etc/，不再往仓库根目录乱丢
;; （原先根目录躺着 recentf / history / bookmarks / projects / tramp / transient/ …，
;; .gitignore 得一条条列）。
;; ⚠ 必须在 require 各模块**之前**加载：它靠改 `recentf-save-file' / `savehist-file'
;; 这类变量生效，晚于相关包初始化就来不及了。
(unless (package-installed-p 'no-littering)
  (package-install 'no-littering))
(require 'no-littering)
(no-littering-theme-backups)            ; 备份/自动保存文件也一并收编

(dolist (package
         '(evil
           evil-surround
           evil-visualstar
           evil-commentary
           posframe
           multiple-cursors
           ace-window
           hydra
           rainbow-delimiters
           nerd-icons
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
(require 'init-bars)                    ; mode-line + tab-line（须在 init-ui 之后：复用其字体选择结果）
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

;; ---- emacs.pdmp 新鲜度自检 ----
;; 映像里烤着 elpa/ 下那批包的代码。装/删包后若不重跑 `make dump'，映像照样能启动，
;; 但跑的是**旧代码**——这种「静默用着旧包」比启动直接失败更难发现。
;; （升级 emacs 那种不兼容会启动即报错，不需要额外提醒。）
;; 把 AGENTS.md 里的口头约定落成一次实际检查：仅在确实用本仓库 dump 启动时才判。
(defun my/check-pdmp-freshness ()
  "用本仓库 emacs.pdmp 启动时，若映像早于 elpa/ 最后改动则告警。"
  (when-let* ((stats (and (fboundp 'pdumper-stats) (pdumper-stats)))
              (dump (alist-get 'dump-file-name stats))
              (ours (expand-file-name "emacs.pdmp" user-emacs-directory))
              ((file-exists-p ours))
              ((file-equal-p dump ours))
              (elpa (expand-file-name "elpa" user-emacs-directory))
              ((file-directory-p elpa))
              (dump-time (file-attribute-modification-time (file-attributes ours)))
              (elpa-time (file-attribute-modification-time (file-attributes elpa)))
              ((time-less-p dump-time elpa-time)))
    (display-warning
     'pdmp
     (format "emacs.pdmp（%s）早于 elpa/ 最后改动（%s）：包可能已增删，映像里是旧代码。
请重跑 `make dump' 重建。"
             (format-time-string "%F %R" dump-time)
             (format-time-string "%F %R" elpa-time))
     :warning)))

(add-hook 'emacs-startup-hook #'my/check-pdmp-freshness)

(provide 'init-full)

;;; init-full.el ends here
