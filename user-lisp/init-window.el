;; init-window.el 	-*- lexical-binding: t -*-
(add-hook 'after-init-hook 'winner-mode)

;; 窗口分隔线：比默认的 `vertical-border' 干净（它会和 fringe 挤在一起）。
;; 底部分隔线宽度置 0，只在真的有上下分屏时才由下面的钩子临时给 1，
;; 避免单窗口时 mode-line 底下多出一条没用的线。
(setq window-divider-default-places t
      window-divider-default-right-width 1
      window-divider-default-bottom-width 0)
(add-hook 'after-init-hook #'window-divider-mode)

(defun my/update-bottom-divider ()
  "只有存在上下相邻窗口时才显示底部分隔线。"
  (set-frame-parameter nil 'bottom-divider-width
                       (if (eq (next-window) (selected-window)) 0 1)))
(add-hook 'window-configuration-change-hook #'my/update-bottom-divider)

;; 关闭当前窗口：有分屏就删掉该窗口（分屏消失），单一窗口时退回 bury；
;; 带前缀 C-u 时额外 kill 该窗口的 buffer。临时只读 buffer（VC/help/xref…）的 q 用它。
;; 例外：VC 提交 buffer（log-edit）的 q 应是"放弃本次提交"——提交只在 `log-edit-done'
;; 里发生，所以 kill 掉该 buffer 即取消；交给 `log-edit-kill-buffer'（= C-c C-k，
;; 会顺手关窗口/hide 文件列表）。这样各处 q 都走同一个 `my/quit-window'。
(defun my/quit-window (arg)
  "关闭当前窗口：分屏时直接删窗，否则 bury。ARG 非 nil 时再 kill buffer。
在 VC 提交 buffer（`log-edit-mode'）里则放弃本次提交并关掉它。"
  (interactive "P")
  (if (derived-mode-p 'log-edit-mode)
      (log-edit-kill-buffer)
    (let ((buf (current-buffer)))
      (if (and (> (length (window-list nil 'nomini)) 1)
               (ignore-errors (delete-window) t))
          nil
        (quit-window nil))
      (when arg (kill-buffer buf)))))

;; defhydra 来自 hydra 包；显式 require，确保宏在此处可用（否则 fresh 机器
;; 上 hydra 未被自动加载时会报 void-function defhydra）。
(require 'hydra)

(defhydra hydra-window-size (:color red)
  "调整窗口大小"
  ("h" shrink-window-horizontally "向左缩窄")
  ("j" enlarge-window "向下拉高")
  ("k" shrink-window "向上缩短")
  ("l" enlarge-window-horizontally "向右加宽")
  ("q" nil "退出"))

(defhydra hydra-winner (:color red)
  "窗口布局撤销/重做"
  ("u" winner-undo "回退布局")
  ("r" winner-redo "前进布局")
  ("q" nil "退出"))


;; (require 'popper)
(with-eval-after-load 'popper
  (setq popper-window-height 20)
  (setq popper-reference-buffers
        '("\\*Messages\\*"
          "Output\\*$"
          "\\*Async Shell Command\\*"
          "^\\*Copilot"
          "^\\*.*eshell.*\\*$" eshell-mode ;eshell as a popup
          "^\\*.*shell.*\\*$"  shell-mode  ;shell as a popup
          "^\\*.*term.*\\*$"   term-mode   ;term as a popup
          "^\\*.*vterm.*\\*$"  vterm-mode  ;vterm as a popup
          ;; eldoc 文档窗口（`gh' = my/doc-at-point 弹出）。⚠ 必须写成前缀匹配：
          ;; 这个 buffer 显示时会被 `eldoc--format-doc-buffer' 改名成 `*eldoc for xxx*'，
          ;; 名字随光标下的符号变，写死 "^\\*eldoc\\*$" 一条都匹配不上。
          "^\\*eldoc"
          "^\\*Buffer List.*\\*$"
          "\\*Ibuffer.*\\*" ibuffer-mode ;ibuffer-mode
          help-mode
          ;; VC 提交 buffer（`C-x v v' 弹出的 *vc-log*）也走弹窗。
          ;; 原 `COMMIT_EDITMSG' / `git-commit-ts-mode' 是 magit 时代的，已随 magit 移除。
          ;; buffer 名固定是 *vc-log*（vc-start-logentry），用名字正则最稳——popper 对 mode 项
          ;; 是按 major-mode **精确**匹配，而它是 vc-git-log-edit-mode，写 log-edit-mode 不中。
          "^\\*vc-log\\*$"
          compilation-mode))
  )
(popper-mode +1)

(provide 'init-window)
