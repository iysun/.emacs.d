;;; -*- lexical-binding: t; -*-
;; (require 'magit)

;; Windows 上给 git 子进程定的环境变量已挪到 lisp/init-windows.el（early-init.el
;; 阶段就设好，比这里更早，覆盖面也更全——不止 magit 会起 git 子进程）。

;; Magit 配置
(with-eval-after-load 'magit
  (unbind-key "M-1" magit-mode-map)
  (unbind-key "M-2" magit-mode-map)
  (unbind-key "M-3" magit-mode-map)
  (unbind-key "M-4" magit-mode-map)

  ;; magit-status 提速：默认会在 status 里渲染完整 diff + 一大段 log，
  ;; 大仓库下这是主要耗时来源。
  (setq magit-commit-show-diff nil            ; 写 commit message 时不同时铺开 diff
        magit-log-section-commit-count 5      ; status 里近期提交只列 5 条（默认 10）
        magit-refresh-verbose nil))

;; diff-hl 已移除：diff-hl-flydiff-mode 靠全局 0.3s idle timer 给每个改过的
;; buffer 起 git diff 子进程算 hunk，Windows 上 CreateProcess 本来就比 POSIX
;; fork+exec 贵得多（本机 eshell-git-prompt 实测过单次 git 子进程两三百毫秒起步），
;; 叠加起来是敲代码卡顿的一个来源；另外 async 子进程输出偶尔混进 git 的 CRLF
;; 警告，会让 diff-hl 内部的 `diff-beginning-of-hunk' 解析失败，报
;; "error in process sentinel: Can't find the beginning of the hunk"。
;; 改动历史见 git log；未改动状态跟踪继续靠 magit（`magit-status` 里能看
;; 完整的 unstaged/staged diff）。

;; 打开文件时若检测到冲突标记就自动开 smerge-mode（省去手动 M-x）。
;; 只扫文件开头到第一个匹配，代价可忽略。
(defun my/auto-smerge-mode ()
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^<<<<<<< " nil t)
      (smerge-mode 1))))
(add-hook 'find-file-hook #'my/auto-smerge-mode)

(provide 'init-git)
