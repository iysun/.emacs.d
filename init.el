;;; init.el --- 全量启动配置 -*- lexical-binding: t; -*-

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

(require 'package)
(require 'init-mirrors)
;; ⚠ 用 package--activated 判（quickstart 下 package--initialized 仍是 nil）
(unless (bound-and-true-p package--activated)
  (package-initialize))

(require 'use-package)

;; 把各包运行期文件收进 var/ 与 etc/
;; ⚠ 必须早于各模块 require：它靠改 recentf-save-file / savehist-file 生效
(unless (package-installed-p 'no-littering)
  (package-install 'no-littering))
(require 'no-littering)
(no-littering-theme-backups)

(dolist (package
         '(evil
           posframe
           multiple-cursors
           hydra
           nerd-icons
           popper
           consult
           embark
           embark-consult
           marginalia
           consult-eglot
           ;; ⚠ 别装 eshell-git-prompt：multiline2 每画一次提示符起 4 个 git 进程
           eshell-syntax-highlighting
           orderless
           vertico
           corfu
           corfu-terminal
           cape
           apheleia))
  (eval `(use-package ,package :ensure t :defer t)))
;; evil-surround / visualstar / commentary / gcmh 已内联进仓库，不从 elpa 装

(when (executable-find "fd")
  (use-package fd-dired :ensure t :defer t))

(require 'init-base)
;; ⚠ evil 留到 after-init（不计入 emacs-init-time）；depth -99 保证早于字体/补全等其它 after-init 工作
(add-hook 'after-init-hook (lambda () (require 'evil-config)) -99)
(require 'init-ui)
(require 'init-parens)
(require 'init-bars)
(require 'init-window)
(require 'init-completion)
(require 'init-dired)
(require 'init-git)
(require 'init-term)
(require 'init-project)
(require 'mc-evil)

(require 'evil-keymaps)
(require 'evil-vc)
(require 'evil-dired)
(require 'evil-ibuffer)
(require 'evil-extra)
(require 'init-keymaps)
(require 'init-lsp)
(require 'init-format)
(require 'init-navigation)

;; ⚠ quickstart 快照过期不报错、静默用旧包集合，故自检：快照早于 elpa/ 就告警
(defun my/check-quickstart-freshness ()
  "用 package-quickstart 启动时，若快照早于 elpa/ 最后改动则告警。"
  (when (and (bound-and-true-p package-quickstart)
             (bound-and-true-p package-quickstart-file))
    (let* ((qs (or (and (file-exists-p (concat package-quickstart-file "c"))
                        (concat package-quickstart-file "c"))
                   (and (file-exists-p package-quickstart-file)
                        package-quickstart-file)))
           (elpa (expand-file-name "elpa" user-emacs-directory)))
      (when (and qs (file-directory-p elpa)
                 (time-less-p (file-attribute-modification-time (file-attributes qs))
                              (file-attribute-modification-time (file-attributes elpa))))
        (display-warning
         'quickstart
         (format "package-quickstart（%s）早于 elpa/ 最后改动（%s）：可能装/删过包，快照是旧的。请 M-x package-quickstart-refresh 重建。"
                 (format-time-string "%F %R" (file-attribute-modification-time (file-attributes qs)))
                 (format-time-string "%F %R" (file-attribute-modification-time (file-attributes elpa))))
         :warning)))))
(add-hook 'emacs-startup-hook #'my/check-quickstart-freshness)

(provide 'init)
