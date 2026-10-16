;; mc-evil.el   -*- lexical-binding: t -*-

(defvar-local my/mc-prev-evil-state nil
  "进入 multiple-cursors 前的 evil 状态；退出时据此恢复。
buffer-local —— 与 mc 自身的 `multiple-cursors-mode'（也是 buffer-local）作用域一致，
避免旧版那种「全局标志 + 本地标志」错配、跨 buffer 误判 / 永久粘住的问题。")

(defun my/mc-enter (&rest _)
  "进入 mc：记下当前 evil 状态并切到 emacs-state。幂等（已在 emacs-state 则不动）。
若当前是 visual 选区：evil 的 visual 选择是 inclusive，而 \(mark\)/\(point\) 给 emacs 的
区是 exclusive，会少末尾一个字符（mc 标记的文本被截断），故按 evil-visual-beginning/end
的 inclusive 边界取，切 emacs-state 后再还原成 active region 交给 mc。
（evil 退出 visual 后 `transient-mark-mode' 可能为 nil，仅 `set-mark' 不足以让
`region-active-p' 为真，故还要 `activate-mark'。）"
  (when (and (bound-and-true-p evil-local-mode)
             (not (evil-emacs-state-p)))
    (let ((was-visual (evil-visual-state-p))
          beg end)
      (when was-visual
        (setq beg (or (and (markerp evil-visual-beginning)
                           (marker-position evil-visual-beginning))
                      (region-beginning))
              end (or (and (markerp evil-visual-end)
                           (marker-position evil-visual-end))
                      (region-end))))
      (setq my/mc-prev-evil-state (or evil-state 'normal))
      (evil-emacs-state)
      (when was-visual
        (set-mark beg)
        (goto-char end)
        (setq deactivate-mark nil)
        (activate-mark)))))

(defun my/mc-enter-visual (&rest _)
  "供「吃选区」命令的 :before 用：只在该命令**带 visual 选区**时才做换算与切换。
无选区时不抢先切 emacs-state——否则该命令若没真的起 mc（如 edit-lines 无选区），
就会卡在 emacs-state 无人恢复；无选区的情形交给 `multiple-cursors-mode-enabled-hook'。"
  (when (evil-visual-state-p)
    (my/mc-enter)))

(defun my/mc-leave ()
  "mc 关闭：恢复到进入前的 evil 状态（visual 还原为 normal，其选区已失效）。"
  (when (and my/mc-prev-evil-state
             (bound-and-true-p evil-local-mode))
    (let ((prev my/mc-prev-evil-state))
      (setq my/mc-prev-evil-state nil)
      (evil-change-state (if (eq prev 'visual) 'normal prev)))))

(add-hook 'multiple-cursors-mode-enabled-hook  #'my/mc-enter)
(add-hook 'multiple-cursors-mode-disabled-hook #'my/mc-leave)

;; ⚠「吃选区」的命令须在执行前换算 visual 选区：mc 在首个命令之后才 enable，等 hook 来不及。
(dolist (cmd '(mc/edit-lines
               mc/mark-all-in-region
               mc/mark-all-in-region-regexp
               mc/mark-all-dwim
               mc/mark-lines
               mc/mark-next-lines
               mc/mark-previous-lines
               mc/edit-beginnings-of-lines
               mc/edit-ends-of-lines
               mc/insert-numbers
               mc/insert-letters
               mc/vertical-align
               mc/vertical-align-with-space
               mc/reverse-regions
               mc/sort-regions))
  (when (fboundp cmd)
    (unless (advice-member-p #'my/mc-enter-visual cmd)
      (advice-add cmd :before #'my/mc-enter-visual))))

(provide 'mc-evil)
