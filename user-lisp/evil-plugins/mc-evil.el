;; mc-evil.el   -*- lexical-binding: t -*-
;;
;; multiple-cursors 与 evil 联动：mc 激活时切到 evil 的 emacs-state（这样输入/命令会被
;; mc 广播到所有光标），mc 关闭时恢复**进入前**的 evil 状态。
;;
;; 状态切换靠 mc 自己的 `multiple-cursors-mode-enabled/disabled-hook'——它覆盖**所有**
;; 起手路径（任何 mc 命令、乃至 `M-x'），不必再维护一份"哪些命令要 advice"的清单：
;; 旧版硬编码 13 个命令，漏了 20 个（mc/mark-all-dwim、mc/mark-more-like-this(-extended)、
;; mc/mark-next/previous-word-like-this、mc/mark-all-words/symbols-like-this、mc/mark-lines、
;; mc/unmark-*、mc/edit-beginnings/ends-of-lines ……），从这些起手时联动直接失效。
;;
;; 例外：**吃选区**的那批命令要在**执行前**就把 visual 选区换算好——mc 是在首个命令
;; **之后**才 enable 的，等 enabled-hook 触发就来不及了。故只给它们加 :before（只列语义
;; 明确的"吃选区"命令，不会像旧版那样漏）。

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

;; 覆盖所有起手路径。
(add-hook 'multiple-cursors-mode-enabled-hook  #'my/mc-enter)
(add-hook 'multiple-cursors-mode-disabled-hook #'my/mc-leave)

;; 「吃选区」的命令：执行前换算 visual 选区（见文件头）。
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
    ;; 幂等：重复 load 本文件不会叠加 advice。
    (unless (advice-member-p #'my/mc-enter-visual cmd)
      (advice-add cmd :before #'my/mc-enter-visual))))

;; 键位见 init-keymaps.el（M-j / M-k、C-M-n / C-M-p / C-M-m / C-M-a / C-M-l）。

(provide 'mc-evil)
