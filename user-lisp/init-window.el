;; init-window.el 	-*- lexical-binding: t -*-
(add-hook 'after-init-hook 'winner-mode)

(windmove-default-keybindings)

(setq window-divider-default-places t
      window-divider-default-right-width 1
      window-divider-default-bottom-width 1)
(add-hook 'after-init-hook #'window-divider-mode)

(defun my/update-bottom-divider ()
  "托盘开着时，底部分割线是 1px 亮线，下面再留和 tab-line 相同的上边距。
宽度没变时不写 frame 参数，避免每次 :w 都触发布局。关掉托盘后只留 1px。
⚠ 文本终端没有像素分割线，宽度按整行算，pad 必须为 0。"
  (let* ((pad (if (and (display-graphic-p)
                       (bound-and-true-p my/ui-echo-tray-mode)
                       (boundp 'my/ui-bar-padding))
                  my/ui-bar-padding
                0))
         (width (1+ pad)))
    (unless (eql (frame-parameter nil 'bottom-divider-width) width)
      (set-frame-parameter nil 'bottom-divider-width width))))
(add-hook 'window-configuration-change-hook #'my/update-bottom-divider)

;; ⚠ q 在 log-edit buffer 里须走 log-edit-kill-buffer 放弃提交
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

;; ⚠ 显式 require：不取 defhydra 宏会 void-function
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

(with-eval-after-load 'popper
  (setq popper-window-height 20)
  (setq popper-reference-buffers
        '("\\*Messages\\*"
          "Output\\*$"
          "\\*Async Shell Command\\*"
          "^\\*Copilot"
          "^\\*.*eshell.*\\*$" eshell-mode
          "^\\*.*shell.*\\*$"  shell-mode
          "^\\*.*term.*\\*$"   term-mode
          "^\\*.*vterm.*\\*$"  vterm-mode
          ;; ⚠ 须前缀匹配：eldoc 文档 buffer 显示时被改名
          "^\\*eldoc"
          "^\\*Buffer List.*\\*$"
          "\\*Ibuffer.*\\*" ibuffer-mode
          help-mode
          "^\\*vc-log\\*$"
          "^\\*vc-[a-z0-9]+ : "
          compilation-mode))
  )
(popper-mode +1)

(provide 'init-window)
