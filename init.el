;;; init.el --- 全量启动配置 -*- lexical-binding: t; -*-
;;
;; 模块化完整配置：evil、补全栈、UI、LSP、VC 等。
;;
;; 加载路径：`user-lisp/' 及其子目录（mode-line/tab-line/eshell-prompt）由 Emacs 31
;; 的 user-lisp 机制自动处理——`prepare-user-lisp' 在启动时把它们加入 load-path，
;; 并按需字节编译/生成 autoload，因此这里直接 `require' 即可，不再手动改 load-path。
;; GC 延迟由 `early-init.el' 处理；custom-file 在此加载。

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

(require 'package)
(require 'init-mirrors)                 ; package-archives 的唯一定义处
;; 包已由 early-init 通过 `package-activate-all' 激活；这里仅在未激活时兜底
;; （例如 --batch 直接 -l init.el）。⚠ 走 quickstart 时 `package--initialized' 仍为 nil，
;; 故用 `package--activated'（package-activate-all 会置它）判，别用 package--initialized。
(unless (bound-and-true-p package--activated)
  (package-initialize))

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
           posframe
           multiple-cursors
           hydra
           rainbow-delimiters
           nerd-icons
           popper
           consult
           embark
           embark-consult
           marginalia
           consult-eglot
           ;; eshell-git-prompt 已移除：它的 multiline2 主题每画一次提示符要起 4 个
           ;; git 进程（本机实测 945ms/条命令）。提示符改为 user-lisp/init-term.el 里自写，
           ;; 分支名读 .git/HEAD、脏净标记异步算，见那里的说明。
           eshell-syntax-highlighting
           orderless
           vertico
           corfu
           corfu-terminal
           cape
           apheleia))
  (eval `(use-package ,package :ensure t :defer t)))
;; evil-surround / evil-visualstar / evil-commentary / gcmh 已内联进仓库
;; （user-lisp/evil-plugins/、user-lisp/gcmh/），不再从 elpa 装/激活。

(when (executable-find "fd")
  ;; 不要 eager `(require 'fd-dired)`：它顶层 require find-dired/ibuffer/ibuf-ext，
  ;; find-dired 又拉起 dired，实测明显拖慢启动。`use-package ... :defer t' 已生成
  ;; autoload，首次用 `M-x fd-dired` 时再加载。
  (use-package fd-dired :ensure t :defer t))

(require 'init-base)
;; evil 延迟到 after-init 加载，使其不计入 `emacs-init-time'。
;; evil-plugins/evil-config.el 内部做 (require 'evil)+(evil-mode 1)；
;; evil-keymaps/init-completion 顶层已改为 eval-when-compile，故 init 期不会把 evil
;; 拉起来。depth -99 保证它早于 after-init 的其它工作（字体 -95、use-completion-style 等）。
(add-hook 'after-init-hook (lambda () (require 'evil-config)) -99)
(require 'init-ui)
(require 'init-bars)                    ; mode-line + tab-line（须在 init-ui 之后：复用其字体选择结果）
(require 'init-window)
(require 'init-completion)
(require 'init-dired)
(require 'init-git)
(require 'init-term)
(require 'init-project)
(require 'mc-evil)

(require 'evil-keymaps)                 ; evil 专属键位（with-eval-after-load 'evil）
(require 'evil-vc)                      ; 自 evil-collection 提取的 VC / diff-mode 键位
(require 'evil-dired)                   ; 自 evil-collection 提取的 dired 键位
(require 'evil-ibuffer)                 ; 自 evil-collection 提取的 ibuffer 键位
(require 'evil-extra)                   ; 自 evil-collection 提取的其它 special mode 键位
(require 'init-keymaps)                 ; 非 evil 全局键
(require 'init-lsp)
(require 'init-format)
(require 'init-navigation)

;; ---- package-quickstart 新鲜度自检 ----
;; quickstart 快照过期时 `package-activate-all' **不报错**、静默用旧集合（新装的包会
;; 「装了却没激活」）。这里仿旧 pdmp 自检：快照早于 elpa/ 最后改动就告警。
;; 装/删包走 package.el 会自动重建（`package--quickstart-maybe-refresh'），手工改 elpa/ 不会。
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
;;; init.el ends here
