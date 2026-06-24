;; init.el 	-*- lexical-binding: t -*-

;; `evil-define-key' 是宏，编译期必须先加载 evil，否则被当函数编译成坏 .elc
;; （加载时报 "Invalid function: evil-define-key"）。顶层 require 同时满足编译期与源码加载。
(require 'evil)
(defvar eshell-mode-map)
(defvar capf-autosuggest-active-mode-map)
(defvar dired-mode-map)
(defvar eat-mode-map)
(defvar minuet-active-mode-map)

(defun custom/downcase-back()
  (interactive)
  (downcase-word -1))
(defun custom/upcase-back()
  (interactive)
  (upcase-word -1))
(defun custom/capitalize-back()
  (interactive)
  (capitalize-word -1))

(defun init-keymaps--bind-diff-hl-local ()
  (dolist (state '(normal insert visual))
    (evil-define-key state 'local (kbd "M-p") 'diff-hl-previous-hunk)
    (evil-define-key state 'local (kbd "M-n") 'diff-hl-next-hunk)
    (evil-define-key state 'local (kbd "M-,") 'diff-hl-revert-hunk)
    (evil-define-key state 'local (kbd "M-.") 'diff-hl-stage-dwim)
    (evil-define-key state 'local (kbd "C-c h v") 'diff-hl-show-hunk)))

;; 在 evil 加载后用原生 keymap API 绑定（global-set-key / define-key / evil-define-key）
(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "SPC f") 'eglot-format)

  ;; 全局键（原 general-def 无 :keymaps）
  (global-set-key (kbd "C-;") 'embark-act)
  (global-set-key (kbd "C-h b") 'embark-bindings)

  (global-set-key (kbd "M-k") 'mc/mark-previous-like-this)
  (global-set-key (kbd "M-j") 'mc/mark-next-like-this)
  (global-set-key (kbd "M-<down>") 'mc/mark-next-like-this-word)

  (global-set-key (kbd "C-x C-r") 'project-switch-project)
  (global-set-key (kbd "C-x C-b") 'ibuffer)
  (global-set-key (kbd "C-x M-:") 'consult-complex-command)
  (global-set-key (kbd "C-x b") 'consult-buffer)
  (global-set-key (kbd "C-x 4 b") 'consult-buffer-other-window)
  (global-set-key (kbd "C-x 5 b") 'consult-buffer-other-frame)
  (global-set-key (kbd "C-x t b") 'consult-buffer-other-tab)
  (global-set-key (kbd "C-x p b") 'consult-project-buffer)
  ;; 原生 tab-line 无「按组关 buffer」对应功能，暂去掉（如需可自行实现）
  ;; (global-set-key (kbd "C-x C-k") 'centaur-tabs-kill-all-buffers-in-current-group)
  ;; (global-set-key (kbd "C-x C-o") 'centaur-tabs-kill-other-buffers-in-current-group)
  (global-set-key (kbd "M-#") 'consult-register-load)
  (global-set-key (kbd "M-'") 'consult-register-store)
  (global-set-key (kbd "C-M-#") 'consult-register)
  (global-set-key (kbd "C-c M-x") 'consult-mode-command)
  (global-set-key (kbd "C-c h") 'consult-history)
  (global-set-key (kbd "C-c k") 'consult-kmacro)
  (global-set-key (kbd "C-c c") 'compile)
  (global-set-key (kbd "C-c m") 'consult-man)
  (global-set-key (kbd "C-c i") 'consult-info)
  (global-set-key (kbd "C-c e") 'eshell)
  (global-set-key (kbd "C-c u") 'winner-undo)
  (global-set-key (kbd "C-c r") 'winner-redo)

  (global-set-key (kbd "M-y") 'consult-yank-pop)
  (global-set-key (kbd "C-:") 'shell-command)

  (global-set-key (kbd "M-g b") 'consult-bookmark)
  (global-set-key (kbd "M-g e") 'consult-compile-error)
  (global-set-key (kbd "M-g f") 'consult-flymake)
  (global-set-key (kbd "M-g g") 'consult-goto-line)
  (global-set-key (kbd "M-g o") 'consult-outline)
  (global-set-key (kbd "M-g m") 'consult-mark)
  (global-set-key (kbd "M-g k") 'consult-global-mark)
  (global-set-key (kbd "M-g i") 'consult-imenu)
  (global-set-key (kbd "M-g I") 'consult-imenu-multi)
  (global-set-key (kbd "M-g w") 'ace-window)
  ;; (global-set-key (kbd "M-g t") 'centaur-tabs-ace-jump) ; 原生 tab-line 无 ace-jump 对应
  (global-set-key (kbd "M-g p") 'consult-project-buffer)

  (global-set-key (kbd "M-s f") 'consult-fd)
  (global-set-key (kbd "M-s c") 'consult-locate)
  (global-set-key (kbd "M-s g") 'consult-grep)
  (global-set-key (kbd "M-s G") 'consult-git-grep)
  (global-set-key (kbd "M-s r") 'consult-ripgrep)
  (global-set-key (kbd "M-s l") 'consult-line)
  (global-set-key (kbd "M-s L") 'consult-line-multi)
  (global-set-key (kbd "M-s k") 'consult-keep-lines)
  (global-set-key (kbd "M-s u") 'consult-focus-lines)
  (global-set-key (kbd "M-s e") 'consult-isearch-history)

  (global-set-key (kbd "C->") 'tab-line-switch-to-next-tab)
  (global-set-key (kbd "C-<") 'tab-line-switch-to-prev-tab)

  (global-set-key (kbd "C-M-k") 'bookmark-delete)
  (global-set-key (kbd "C--") 'popper-toggle)
  (global-set-key (kbd "C-=") 'popper-cycle)

  ;; eshell-mode-map 每次进入 eshell-mode 都会被重建，evil-collection 经
  ;; eshell-first-time-mode-hook 重设键位（其中把 insert 态 RET 绑成 newline → 回车只换行不执行）。
  ;; 因此这些绑定必须放在 eshell-mode-hook（晚于 first-time 钩子）里、且 depth 靠后，才能覆盖。
  (defun my/eshell-evil-insert-keys ()
    (evil-define-key 'insert eshell-mode-map (kbd "RET") 'eshell-send-input)        ; 回车=执行命令
    (evil-define-key 'insert eshell-mode-map (kbd "<return>") 'eshell-send-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-p") 'eshell-previous-matching-input-from-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-n") 'eshell-next-matching-input-from-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-r") 'consult-history)
    (evil-normalize-keymaps))
  (add-hook 'eshell-mode-hook #'my/eshell-evil-insert-keys 90)

  (with-eval-after-load 'capf-autosuggest
    (evil-define-key 'insert capf-autosuggest-active-mode-map (kbd "C-f") 'capf-autosuggest-end-of-line))

  (dolist (state '(normal insert visual))
    (evil-define-key state dired-mode-map (kbd "C-a") 'dired-create-empty-file)
    (evil-define-key state dired-mode-map (kbd "C-d") 'dired-create-directory))

  (with-eval-after-load 'eat
    (define-key eat-mode-map (kbd "M-g w") 'ace-window)
    (define-key eat-mode-map (kbd "C-w C-w") 'other-window)
    (define-key eat-mode-map (kbd "C-w c") 'delete-window)
    (define-key eat-mode-map (kbd "C--") 'popper-toggle)
    (define-key eat-mode-map (kbd "M--") 'popper-cycle))

  (add-hook 'prog-mode-hook #'init-keymaps--bind-diff-hl-local)
  (add-hook 'text-mode-hook #'init-keymaps--bind-diff-hl-local)

  (evil-define-key 'normal 'global (kbd "gh") 'eldoc-mouse-pop-doc-at-cursor)

  (with-eval-after-load 'minuet
    (evil-define-key 'insert minuet-active-mode-map (kbd "<tab>") 'minuet-accept-suggestion)
    (evil-define-key 'insert minuet-active-mode-map (kbd "M-p") 'minuet-previous-suggestion)
    (evil-define-key 'insert minuet-active-mode-map (kbd "M-n") 'minuet-next-suggestion))

  (evil-define-key 'visual 'global (kbd "Y") 'clipboard-kill-ring-save)

  ;; multiple-cursors（mc/）键位。用 global-set-key 而非 evil-define-key：触发后
  ;; my/disable-evil-for-mc 会切到 emacs-state，全局绑定在 normal 与 emacs 两态都生效，
  ;; 这样在已有多光标时还能继续加/跳光标。（evil-mc 未安装，原绑定是 void。）
  (global-set-key (kbd "C-M-n") 'mc/mark-next-like-this)
  (global-set-key (kbd "C-M-p") 'mc/mark-previous-like-this)
  (global-set-key (kbd "C-M-m") 'mc/skip-to-next-like-this)
  (global-set-key (kbd "C-M-a") 'mc/mark-all-like-this)
  (global-set-key (kbd "C-M-l") 'mc/edit-lines)

  (evil-define-key 'insert 'global (kbd "C-v") 'clipboard-yank)
  (evil-define-key 'insert 'global (kbd "C-a") 'beginning-of-line)
  (evil-define-key 'insert 'global (kbd "C-e") 'end-of-line)
  (evil-define-key 'insert 'global (kbd "C-k") 'kill-line)
  (evil-define-key 'insert 'global (kbd "C-d") 'delete-char)
  (evil-define-key 'insert 'global (kbd "M-u") 'custom/upcase-back)
  (evil-define-key 'insert 'global (kbd "M-l") 'custom/downcase-back)
  (evil-define-key 'insert 'global (kbd "M-c") 'custom/capitalize-back))

(provide 'init-keymaps)
