;; evil-vc.el 	-*- lexical-binding: t -*-
;; 内联自 evil-collection（20260623.308，GPLv3）的 VC 键位：vc-dir / diff-mode / vc-annotate / log-view / log-edit / special-mode
;; 展开成真实按键；`evil-define-key' 是宏（编译期 require evil）、目标 map 未建好时它会自己推迟。

(eval-when-compile (require 'evil))

;; 只读模式把插入/修改类命令 remap 成 ignore（对应 evil-collection-inhibit-insert-state）；eval-and-compile：宏编译期要读它
(eval-and-compile
  (defconst evil-vc--readonly-commands
    '(evil-append evil-append-line evil-insert evil-insert-line
      evil-change evil-change-line evil-substitute evil-change-whole-line
      evil-delete evil-delete-line evil-delete-char evil-delete-backward-char
      evil-replace evil-replace-state evil-open-below evil-open-above
      evil-paste-after evil-paste-before evil-join evil-indent
      evil-shift-left evil-shift-right evil-invert-char)))

;; 只读收尾 q/ZZ/ZQ + remap；必须传字面量 map 符号
(defmacro evil-vc--readonly-bindings (map)
  "Apply evil-collection's read-only bindings to literal keymap MAP."
  `(evil-define-key 'normal ,map
     (kbd "ZZ") 'quit-window
     (kbd "ZQ") 'evil-quit
     ,@(apply #'append
              (mapcar (lambda (c) `((vector 'remap ',c) #'ignore))
                      evil-vc--readonly-commands))))

(defun my/diff-toggle-context-unified (start end)
  "Toggle between context and unified diff views.
START and END are either taken from the region or cover the whole buffer."
  (interactive (if (or current-prefix-arg (use-region-p))
                   (list (region-beginning) (region-end))
                 (list (point-min) (point-max))))
;; 没有直接办法判断 context/unified，用 point-max 是否变化来猜
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


  (evil-set-initial-state 'vc-dir-mode 'normal)
  (evil-define-key 'normal vc-dir-mode-map
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
    (kbd "Bc")        'vc-create-tag
    (kbd "Bl")        'vc-print-branch-log
    (kbd "Bs")        'vc-retrieve-tag
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
  (evil-vc--readonly-bindings vc-dir-mode-map)

  (evil-set-initial-state 'diff-mode 'normal)
  (evil-define-key 'normal diff-mode-map
    (kbd "ge")  'diff-ediff-patch
    (kbd "\\")  'read-only-mode
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
    (kbd "RET")       'diff-goto-source
    (kbd "<return>")  'diff-goto-source
    (kbd "gj")        'diff-hunk-next
    (kbd "gk")        'diff-hunk-prev
    (kbd "]]")        'diff-file-next
    (kbd "[[")        'diff-file-prev
    (kbd "C-j")       'diff-hunk-next
    (kbd "C-k")       'diff-hunk-prev
    (kbd "gr")        'revert-buffer)

  (evil-set-initial-state 'vc-annotate-mode 'normal)
  (evil-define-key 'normal vc-annotate-mode-map
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

  (evil-set-initial-state 'vc-hg-log-view-mode 'normal)
  (evil-set-initial-state 'vc-git-log-view-mode 'normal)
  (evil-set-initial-state 'vc-svn-log-view-mode 'normal)
  (evil-define-key 'normal log-view-mode-map
    (kbd "c")         'log-view-modify-change-comment
    ;; R/x/X/e/C 是 log-view 自带键位，被 evil normal 态的单字母命令占了，故显式补回
    ;; ⚠ x/X 改写历史（Emacs 侧自带确认；已推送历史默认被 vc-allow-rewriting-published-history 拦住）
    (kbd "R")         'log-view-revert-or-delete-revisions
    (kbd "x")         'log-view-uncommit-revisions-from-end
    (kbd "X")         'log-view-delete-revisions-from-end
    (kbd "e")         'log-view-modify-change-comment       ; 与 c 同命令（补上游键位）
    (kbd "C")         'log-view-cherry-pick
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
  (evil-define-key 'normal vc-git-log-view-mode-map
    (kbd "d")         'log-view-diff
    (kbd "D")         'log-view-diff-changeset
    (kbd "<tab>")     'log-view-toggle-entry-display
    (kbd "gj")        'log-view-msg-next
    (kbd "gk")        'log-view-msg-prev
    (kbd "]]")        'log-view-msg-next
    (kbd "[[")        'log-view-msg-prev
    (kbd "gr")        'revert-buffer)

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

