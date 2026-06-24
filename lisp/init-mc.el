;; init-mc.el   -*- lexical-binding: t -*-
(defvar my/is-multiple-cursors-mode nil)

;; 自动在 multiple-cursors 模式下禁用 evil，退出后重新启用
;; 用 (&rest _args)：advice 会以被建议命令的参数调用本函数，而 mc 命令 arity 不一
;; （如 mc/mark-all-like-this 是 0 参），写死一个必填参数会触发 wrong-number-of-arguments。
(defun my/disable-evil-for-mc (&rest _args)
  "在 multiple-cursors 模式启用时，局部禁用 evil。"
  (when (not my/is-multiple-cursors-mode)
    (cond
     ((evil-visual-state-p)
      ;; evil 视觉选择是 inclusive，(mark)/(point) 给的 emacs 区是 exclusive，会少末尾一个字符，
      ;; 导致 mc 标记的文本被截断。用 evil-visual-beginning/end（inclusive 边界）取完整选区。
      (let ((beg (or (and (markerp evil-visual-beginning) (marker-position evil-visual-beginning))
                     (region-beginning)))
            (end (or (and (markerp evil-visual-end) (marker-position evil-visual-end))
                     (region-end))))
        (evil-emacs-state)
        (set-mark beg)
        (goto-char end)))
     (t
      (evil-emacs-state)))
    (setq-local my/evil-was-active-before-mc t)
    (setq my/is-multiple-cursors-mode t)
    )
  )

(defun my/restore-evil-after-mc ()
  "在 multiple-cursors 模式禁用时，恢复之前 evil 的状态。"
  (when (and (boundp 'my/evil-was-active-before-mc)
             my/evil-was-active-before-mc)
    (evil-normal-state)
    (setq my/is-multiple-cursors-mode nil)
    (kill-local-variable 'my/evil-was-active-before-mc))) ; 清理变量

;; 添加钩子
;; (add-hook 'multiple-cursors-mode-enabled-hook #'my/disable-evil-for-mc)
(dolist (cmd '(mc/mark-next-like-this
               mc/mark-previous-like-this
               mc/mark-all-like-this
               mc/mark-all-like-this-dwim
               mc/mark-next-like-this-word
               mc/mark-previous-like-this-word
               mc/mark-next-symbol-like-this
               mc/mark-previous-symbol-like-this
               mc/mark-all-in-region
               mc/edit-lines
               mc/skip-to-next-like-this
               mc/skip-to-previous-like-this
               mc/insert-numbers))
  (advice-add cmd :before #'my/disable-evil-for-mc))
(add-hook 'multiple-cursors-mode-disabled-hook #'my/restore-evil-after-mc)

;; 键位见 init-keymaps.el（C-M-n / C-M-p / C-M-m 等）。

(provide 'init-mc)
