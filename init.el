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

(defvar iys/packages
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
    orderless
    vertico
    corfu
    cape
    pinyinlib
    apheleia
    ghostel
    no-littering)
  "本配置从 ELPA 声明的第三方包；vendored 包（如 eshell-syntax-highlighting）不在此列。
`custom.el' 里的 `package-selected-packages' 以这份为准。")

;; 把各包运行期文件收进 var/ 与 etc/
;; ⚠ 必须早于各模块 require：它靠改 recentf-save-file / savehist-file 生效
(unless (package-installed-p 'no-littering)
  (package-install 'no-littering))
(require 'no-littering)
(no-littering-theme-backups)

(when (executable-find "fd")
  (add-to-list 'iys/packages 'fd-dired))
(when (executable-find "readtags")
  (add-to-list 'iys/packages 'citre))

(dolist (package iys/packages)
  (eval `(use-package ,package :ensure t :defer t)))
;; evil-surround / visualstar / commentary / gcmh / eshell-syntax-highlighting 已内联进仓库，不从 elpa 装

;; Emacs 31 自带实验性 markdown-ts-mode，但没打 autoload 也没进 auto-mode-alist
(autoload 'markdown-ts-mode "markdown-ts-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.\\(?:md\\|markdown\\)\\'" . markdown-ts-mode))

;; ⚠ 代码块语言缺 grammar 时会在 font-lock 里弹安装提示，卡死；静默跳过
(with-eval-after-load 'markdown-ts-mode
  (dolist (fn '(markdown-ts--code-block-ts-language
                markdown-ts--fontify-non-ts-collect-faces))
    (advice-add fn :around
                (lambda (orig &rest args)
                  (let ((treesit-auto-install-grammar nil))
                    (apply orig args))))))

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
(require 'init-isearch-pinyin)

;; ⚠ quickstart 快照过期不报错、静默用旧包集合，故自检：快照早于 elpa/ 就告警
(defun iys/check-quickstart-freshness ()
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
(add-hook 'emacs-startup-hook #'iys/check-quickstart-freshness)

(provide 'init)
