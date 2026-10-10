;; evil-vc.el 	-*- lexical-binding: t -*-
;;
;; 自 evil-collection 提取的 VC 相关 evil 键位。
;;
;; 背景：本配置已弃用 evil-collection（见 evil-config.el 顶部说明），但 VC 系列
;; special mode 的 evil 键位原本由它提供。这里把这部分**内联**进来，去掉对
;; evil-collection 的依赖。来源（evil-collection 20260623.308，GPLv3）：
;;   modes/vc-dir      -> evil-collection-vc-dir.el
;;   modes/vc-annotate -> evil-collection-vc-annotate.el
;;   modes/vc-git      -> evil-collection-vc-git.el
;;   modes/log-view    -> evil-collection-log-view.el
;;   modes/log-edit    -> evil-collection-log-edit.el
;;   modes/diff-mode   -> evil-collection-diff-mode.el
;;
;; diff-mode 用 g- 前缀变体（evil-collection-want-g-bindings 默认为 t）。
;;
;; evil-collection 用语义名（`evil-collection-bind'）绑定键位，语义名→按键的
;; 映射取自 `evil-collection-binding-defaults'，下面已展开成真实按键：
;;   mark=m  mark-all=M  unmark=u  unmark-all=U
;;   next-item=gj  prev-item=gk  next-section=]]  prev-section=[[
;;   next-section-2=C-j  prev-section-2=C-k
;;   action=RET/<return>  action-other=S-<return>/S-RET/go  action-stay=M-<return>/M-RET/gO
;;   find-file=gf  refresh=gr  quit=q  quit-save=ZZ  quit-cancel=ZQ
;;   section-toggle=<tab>/TAB  describe-mode=g?
;;
;; `evil-define-key' 是宏，编译期需要 evil；运行时 evil 延迟到 after-init 加载，
;; 故整体包在 `with-eval-after-load 'evil'。目标 map 若尚未建好，`evil-define-key'
;; 会经 `after-load-functions' 自动推迟，无需再套 `with-eval-after-load'。

(eval-when-compile (require 'evil))

;; 只读模式里把插入/修改类命令 remap 成 `ignore'（对应
;; evil-collection-inhibit-insert-state），避免在 vc-dir 里误改。
;; `eval-and-compile'：下面 `evil-vc--readonly-bindings' 宏在**编译期**展开、
;; 需要读到这个列表，故必须让它编译期也有值。
(eval-and-compile
  (defconst evil-vc--readonly-commands
    '(evil-append evil-append-line evil-insert evil-insert-line
      evil-change evil-change-line evil-substitute evil-change-whole-line
      evil-delete evil-delete-line evil-delete-char evil-delete-backward-char
      evil-replace evil-replace-state evil-open-below evil-open-above
      evil-paste-after evil-paste-before evil-join evil-indent
      evil-shift-left evil-shift-right evil-invert-char)))

;; 只读收尾（对应 evil-collection-set-readonly-bindings）：q/ZZ/ZQ + 把插入/修改
;; 类命令 remap 成 ignore。必须是宏、且传**字面量** keymap 符号，evil-define-key
;; 才能对尚未建立的 keymap 自动推迟；remap 项在编译期拼进同一次调用，使每个 mode
;; 只注册 1 个 after-load 延迟项。
(defmacro evil-vc--readonly-bindings (map)
  "Apply evil-collection's read-only bindings to literal keymap MAP."
  `(evil-define-key 'normal ,map
     (kbd "q")  'my/quit-window
     (kbd "ZZ") 'quit-window
     (kbd "ZQ") 'evil-quit
     ,@(apply #'append
              (mapcar (lambda (c) `((vector 'remap ',c) #'ignore))
                      evil-vc--readonly-commands))))

;; diff-mode 的两个 toggle 辅助（原 evil-collection-diff-mode.el 里的同名函数）。
(defun my/diff-toggle-context-unified (start end)
  "Toggle between context and unified diff views.
START and END are either taken from the region or cover the whole buffer."
  (interactive (if (or current-prefix-arg (use-region-p))
                   (list (region-beginning) (region-end))
                 (list (point-min) (point-max))))
  ;; 没有直接办法判断当前是 context 还是 unified，用 point-max 是否变化来猜。
  (let ((old-point-max (point-max)))
    (diff-unified->context start end)
    (when (= old-point-max (point-max))
      (diff-context->unified start end))))

(defun my/diff-toggle-restrict-view (&optional arg)
  "Toggle restriction of the view to the current hunk.
With prefix ARG, restrict to the current file instead."
  (interactive "P")
  (if (buffer-narrowed-p)
      (widen)
    (diff-restrict-view arg)))

(with-eval-after-load 'evil

  ;; ------------------------------------------------------------------ vc-dir
  (evil-set-initial-state 'vc-dir-mode 'normal)
  (evil-define-key 'normal vc-dir-mode-map
    ;; VC 命令
    (kbd "c")         'vc-next-action
    (kbd "d")         'vc-diff
    (kbd "D")         'vc-root-diff
    (kbd "TAB")       'vc-diff
    (kbd "<backtab>") 'vc-root-diff
    (kbd "R")         'vc-register
    (kbd "s")         'vc-register          ; 暂存 / git add
    (kbd "gu")        'vc-update
    (kbd "F")         'vc-update
    (kbd "p")         'vc-push
    (kbd "P")         'vc-push
    (kbd "Lf")        'vc-print-log
    (kbd "Ll")        'vc-print-log
    (kbd "Lr")        'vc-print-root-log
    (kbd "LL")        'vc-print-root-log
    (kbd "Li")        'vc-log-incoming
    (kbd "Lo")        'vc-log-outgoing
    (kbd "x")         'vc-revert
    (kbd "b")         'vc-annotate          ; 逐行 blame
    (kbd "C-c C-c")   'vc-dir-kill-dir-status-process
    (kbd "t")         'vc-dir-toggle-mark
    (kbd "(")         'vc-dir-hide-up-to-date
    (kbd "o")         'vc-dir-hide-up-to-date
    (kbd "X")         'vc-dir-kill-line
    (kbd "S")         'vc-dir-search
    (kbd "Q")         'vc-dir-query-replace-regexp
    (kbd "M-s a C-s")   'vc-dir-isearch
    (kbd "M-s a M-C-s") 'vc-dir-isearch-regexp
    (kbd "i")         'vc-dir-ignore
    ;; 分支
    (kbd "Bc")        'vc-create-tag
    (kbd "Bl")        'vc-print-branch-log
    (kbd "Bs")        'vc-retrieve-tag
    ;; 标记 / 移动 / 动作（原 `evil-collection-bind'）
    (kbd "m")         'vc-dir-mark
    (kbd "M")         'vc-dir-mark-all-files
    (kbd "u")         'vc-dir-unmark
    (kbd "U")         'vc-dir-unmark-all-files
    (kbd "gj")        'vc-dir-next-directory
    (kbd "gk")        'vc-dir-previous-directory
    (kbd "]]")        'vc-dir-next-directory
    (kbd "[[")        'vc-dir-previous-directory
    (kbd "RET")       'vc-dir-find-file
    (kbd "<return>")  'vc-dir-find-file
    (kbd "S-<return>") 'vc-dir-find-file-other-window
    (kbd "S-RET")     'vc-dir-find-file-other-window
    (kbd "go")        'vc-dir-find-file-other-window
    (kbd "M-<return>") 'vc-dir-display-file
    (kbd "M-RET")     'vc-dir-display-file
    (kbd "gO")        'vc-dir-display-file
    (kbd "gf")        'vc-dir-find-file
    (kbd "gr")        'revert-buffer)
  ;; 只读收尾：q/ZZ/ZQ + 禁用插入/修改类命令（1 次调用 = 1 个 after-load 延迟项）
  (evil-vc--readonly-bindings vc-dir-mode-map)

  ;; --------------------------------------------------------------- diff-mode
  (evil-set-initial-state 'diff-mode 'normal)
  (evil-define-key 'normal diff-mode-map
    (kbd "ge")  'diff-ediff-patch
    (kbd "\\")  'read-only-mode
    ;; g- 前缀动作（evil-collection-want-g-bindings 默认 t）
    (kbd "gA")  'diff-add-change-log-entries-other-window
    (kbd "ga")  'diff-apply-hunk
    (kbd "g*")  'diff-refine-hunk
    (kbd "gX")  'diff-file-kill
    (kbd "gx")  'diff-hunk-kill
    (kbd "gi")  'next-error-follow-minor-mode
    (kbd "go")  'my/diff-toggle-restrict-view
    (kbd "g~")  'diff-reverse-direction
    (kbd "gs")  'diff-split-hunk
    (kbd "gc")  'diff-test-hunk
    (kbd "g%")  'my/diff-toggle-context-unified
    (kbd "g#")  'diff-ignore-whitespace-hunk
    ;; 语义名展开
    (kbd "RET")       'diff-goto-source
    (kbd "<return>")  'diff-goto-source
    (kbd "gj")        'diff-hunk-next
    (kbd "gk")        'diff-hunk-prev
    (kbd "]]")        'diff-file-next
    (kbd "[[")        'diff-file-prev
    (kbd "C-j")       'diff-hunk-next
    (kbd "C-k")       'diff-hunk-prev
    (kbd "gr")        'revert-buffer
    (kbd "q")         'my/quit-window)

  ;; ------------------------------------------------------------- vc-annotate
  (evil-set-initial-state 'vc-annotate-mode 'normal)
  (evil-define-key 'normal vc-annotate-mode-map
    (kbd "q")         'my/quit-window
    (kbd "a")         'vc-annotate-revision-previous-to-line
    (kbd "d")         'vc-annotate-show-diff-revision-at-line
    (kbd "=")         'vc-annotate-show-diff-revision-at-line
    (kbd "D")         'vc-annotate-show-changeset-diff-revision-at-line
    (kbd "F")         'vc-annotate-find-revision-at-line
    (kbd "J")         'vc-annotate-revision-at-line
    (kbd "L")         'vc-annotate-show-log-revision-at-line
    (kbd "W")         'vc-annotate-working-revision
    (kbd "A")         'vc-annotate-toggle-annotation-visibility
    (kbd "RET")       'vc-annotate-goto-line
    (kbd "<return>")  'vc-annotate-goto-line
    (kbd "gj")        'vc-annotate-next-revision
    (kbd "gk")        'vc-annotate-prev-revision
    (kbd "]]")        'vc-annotate-next-revision
    (kbd "[[")        'vc-annotate-prev-revision)

  ;; --------------------------------------------------------------- log-view
  ;; 目前 VC 的各 log-view 模式
  (evil-set-initial-state 'vc-hg-log-view-mode 'normal)
  (evil-set-initial-state 'vc-git-log-view-mode 'normal)
  (evil-set-initial-state 'vc-svn-log-view-mode 'normal)
  (evil-define-key 'normal log-view-mode-map
    (kbd "q")         'my/quit-window
    (kbd "c")         'log-view-modify-change-comment
    (kbd "d")         'log-view-diff
    (kbd "=")         'log-view-diff
    (kbd "D")         'log-view-diff-changeset
    (kbd "a")         'log-view-annotate-version
    (kbd "F")         'log-view-find-revision
    (kbd "TAB")       'log-view-toggle-entry-display
    (kbd "<tab>")     'log-view-toggle-entry-display
    (kbd "m")         'log-view-toggle-mark-entry
    (kbd "RET")       'log-view-diff
    (kbd "<return>")  'log-view-diff
    (kbd "gj")        'log-view-msg-next
    (kbd "gk")        'log-view-msg-prev
    (kbd "]]")        'log-view-msg-next
    (kbd "[[")        'log-view-msg-prev
    (kbd "C-j")       'log-view-file-next
    (kbd "C-k")       'log-view-file-prev
    (kbd "gr")        'revert-buffer)
  ;; vc-git 的 log-view 绑定（vc-git-log-view-mode 派生自 log-view-mode）
  (evil-define-key 'normal vc-git-log-view-mode-map
    (kbd "q")         'my/quit-window
    (kbd "d")         'log-view-diff
    (kbd "D")         'log-view-diff-changeset
    (kbd "<tab>")     'log-view-toggle-entry-display
    (kbd "gj")        'log-view-msg-next
    (kbd "gk")        'log-view-msg-prev
    (kbd "]]")        'log-view-msg-next
    (kbd "[[")        'log-view-msg-prev
    (kbd "gr")        'revert-buffer)

  ;; --------------------------------------------------------------- log-edit
  (evil-define-key nil log-edit-mode-map
    [remap evil-save-and-close]          #'log-edit-done
    [remap evil-save-modified-and-close] #'log-edit-done
    [remap evil-quit]                    #'log-edit-kill-buffer)
  (evil-define-key 'normal log-edit-mode-map
    (kbd "g?")        'log-edit-mode-help
    (kbd "ZZ")        'quit-window
    (kbd "ZQ")        'quit-window
    (kbd "gj")        'log-edit-next-comment
    (kbd "gk")        'log-edit-previous-comment
    (kbd "]]")        'log-edit-next-comment
    (kbd "[[")        'log-edit-previous-comment))

(provide 'evil-vc)
;;; evil-vc.el ends here
