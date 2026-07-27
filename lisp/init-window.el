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
          "^\\*.*eat.*\\*$"   eat-mode   ;term as a popup
          "^\\*.*vterm.*\\*$"  vterm-mode  ;vterm as a popup
          "^\\*Buffer List.*\\*$"
          "\\*Ibuffer.*\\*" ibuffer-mode ;ibuffer-mode
          help-mode
          magit-status-mode
          "COMMIT_EDITMSG"                       ;; exact match
          git-commit-ts-mode
          compilation-mode))
  )
(popper-mode +1)

(provide 'init-window)
