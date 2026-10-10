;; init-keymaps.el 	-*- lexical-binding: t -*-
;;
;; 非 evil 的全局键位（embark / multiple-cursors / consult / project / popper /
;; tab-line / bookmark …）。evil 专属键位见 user-lisp/evil-plugins/evil-keymaps.el。

(defun custom/downcase-back()
  (interactive)
  (downcase-word -1))
(defun custom/upcase-back()
  (interactive)
  (upcase-word -1))
(defun custom/capitalize-back()
  (interactive)
  (capitalize-word -1))

;; ---- 全局键 ----
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
;; 按组关 buffer，原生 tab-line 版——实现见 init-bars.el 的
;; my/tab-line-kill-group-buffers / my/tab-line-kill-other-group-buffers。
(global-set-key (kbd "C-x C-k") 'my/tab-line-kill-group-buffers)
(global-set-key (kbd "C-x C-o") 'my/tab-line-kill-other-group-buffers)
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
;; winner-undo/redo 绑到 hydra-winner 的包装函数：首次按键行为不变（直接执行），
;; 之后可用裸键 u/r 连续切换布局，定义见 init-window.el。
(global-set-key (kbd "C-c u") 'hydra-winner/winner-undo)
(global-set-key (kbd "C-c r") 'hydra-winner/winner-redo)

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
;; ace-jump 式按字母跳标签，原生 tab-line 版（C-u C-u 关闭该 tab；
;; 原版 C-u 单前缀「交换 tab 顺序」无法移植，见 my/tab-line-ace-jump 文档字符串）。
(global-set-key (kbd "M-g t") 'my/tab-line-ace-jump)
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

;; multiple-cursors（mc/）键位。用 global-set-key 而非 evil-define-key：触发后
;; my/disable-evil-for-mc 会切到 emacs-state，全局绑定在 normal 与 emacs 两态都生效，
;; 这样在已有多光标时还能继续加/跳光标。（evil-mc 未安装，原绑定是 void。）
(global-set-key (kbd "C-M-n") 'mc/mark-next-like-this)
(global-set-key (kbd "C-M-p") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-M-m") 'mc/skip-to-next-like-this)
(global-set-key (kbd "C-M-a") 'mc/mark-all-like-this)
(global-set-key (kbd "C-M-l") 'mc/edit-lines)

;; smerge 冲突处理 hydra 入口键：复用已有的 C-c ^ 前缀，再按一次 ^ 进入可连续
;; 操作的版本（n/p 跳转冲突，m/o/b/a 保留版本，R 高亮差异）。绑在 smerge-mode-map
;; 上，只在 smerge-mode 开启的 buffer 里生效，不影响全局；定义见 init-git.el。
(with-eval-after-load 'smerge-mode
  (define-key smerge-mode-map (kbd "C-c ^ ^") 'hydra-smerge/body))

(provide 'init-keymaps)
