;;; init.el --- 全量启动配置 -*- lexical-binding: t; -*-
;;
;; 模块化完整配置：evil、补全栈、UI、LSP、magit 等。
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
;; 包已由 early-init 显式初始化；这里仅在未初始化时兜底（例如 --batch 直接 -l init.el）。
(unless (bound-and-true-p package--initialized)
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
           evil-surround
           evil-visualstar
           evil-commentary
           posframe
           multiple-cursors
           ace-window
           hydra
           rainbow-delimiters
           nerd-icons
           popper
           consult
           embark
           embark-consult
           marginalia
           consult-eglot
           magit
           ;; eshell-git-prompt 已移除：它的 multiline2 主题每画一次提示符要起 4 个
           ;; git 进程（本机实测 945ms/条命令）。提示符改为 user-lisp/init-term.el 里自写，
           ;; 分支名读 .git/HEAD、脏净标记异步算，见那里的说明。
           eshell-syntax-highlighting
           orderless
           vertico
           corfu
           corfu-terminal
           cape
           apheleia
           gcmh))
  (eval `(use-package ,package :ensure t :defer t)))

(when (executable-find "fd")
  ;; 不要 eager `(require 'fd-dired)`：它顶层 require find-dired/ibuffer/ibuf-ext，
  ;; find-dired 又拉起 dired，实测明显拖慢启动。`use-package ... :defer t' 已生成
  ;; autoload，首次用 `M-x fd-dired` 时再加载。
  (use-package fd-dired :ensure t :defer t))

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
(require 'init-format)
(require 'init-navigation)

;;(require 'init-ai)
;;(require 'init-evil-plugins)
;;
;;(require 'lang-go)

(provide 'init)
;;; init.el ends here
