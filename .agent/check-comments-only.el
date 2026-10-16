;;; check-comments-only.el --- 校验「只改注释/空白，代码一个 sexp 都没变」  -*- lexical-binding: t -*-
;;
;; 用法（仓库根执行）：
;;   emacs -Q --batch --init-directory "$PWD" -l .agent/check-comments-only.el -- <file>...
;;   emacs ... -l .agent/check-comments-only.el -- --rev=<rev> <file>...   ; 基线默认 HEAD
;;
;; 原理：把基线版本与工作区版本各用 `read' 解析成 sexp 列表后 `equal' 比较——注释、空白、
;; 换行都不影响结果；任何一个 sexp 变了就报错并以非 0 退出。压缩/整理注释时用它自检。

(defconst my/repo (expand-file-name user-emacs-directory))
(defvar my/rev "HEAD")
(defvar my/bad 0)
(defvar my/checked 0)

(defun my/forms (str)
  "把 STR 读成 sexp 列表；读取出错则把错误信息塞在最前面。"
  (with-temp-buffer
    (insert str)
    (goto-char (point-min))
    (let (forms)
      (condition-case err
          (while t (push (read (current-buffer)) forms))
        (end-of-file nil)
        (error (push (format "!!READ-ERROR %S" err) forms)))
      (nreverse forms))))

(defun my/base-content (rel)
  (with-temp-buffer
    (unless (zerop (call-process "git" nil (current-buffer) nil
                                 "-C" my/repo "show" (format "%s:%s" my/rev rel)))
      (insert "!!GIT-SHOW-FAILED"))
    (buffer-string)))

(defun my/check-file (rel)
  (let* ((rel (replace-regexp-in-string "\\\\" "/" rel))
         (abs (expand-file-name rel my/repo))
         (old (my/base-content rel))
         (new (if (file-exists-p abs)
                  (with-temp-buffer (insert-file-contents abs) (buffer-string))
                "!!NOT-FOUND"))
         (fo (my/forms old))
         (fn (my/forms new))
         (ok (equal fo fn)))
    (setq my/checked (1+ my/checked))
    (unless ok
      (setq my/bad (1+ my/bad))
      (let ((i 0))
        (while (and (< i (min (length fo) (length fn))) (equal (nth i fo) (nth i fn)))
          (setq i (1+ i)))
        (princ (format "!!! 代码有变化 %s（第 %d 个 sexp）\n    基线: %S\n    现在: %S\n"
                       rel (1+ i) (nth i fo) (nth i fn)))))
    (princ (format "  %-46s sexp %4d -> %4d  %s\n"
                   rel (length fo) (length fn)
                   (if ok "代码等价 OK" "!!! 代码有变化")))))

(dolist (arg command-line-args-left)
  (cond
   ((string-prefix-p "--rev=" arg) (setq my/rev (substring arg 6)))
   ((member arg '("--" "-q" "-Q")) nil)
   (t (my/check-file arg))))

(princ (format "\n%s：检查 %d 个文件，%d 个代码有变化\n" my/rev my/checked my/bad))
(kill-emacs (if (zerop my/bad) 0 1))
