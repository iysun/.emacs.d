;; -*- lexical-binding: t; -*-

(when (eq system-type 'windows-nt)
  (when (boundp 'w32-get-true-file-attributes)
    (setq w32-get-true-file-attributes nil
          w32-pipe-read-delay 0
          w32-pipe-buffer-size (* 64 1024)))

  ;; ⚠ 不设则中文在 --batch 控制台、跨程序剪贴板乱码
  (set-selection-coding-system 'utf-16le-dos)
  (w32-set-console-codepage 65001)
  (w32-set-console-output-codepage 65001)

  (setenv "GIT_TERMINAL_PROMPT" "0")
  (setenv "GIT_ASK_YESNO" "false")
  (setenv "GIT_PAGER" "cat")
  (setenv "GIT_OPTIONAL_LOCKS" "0")

  ;; ⚠ project.el 无 .git 时用 find-program，PATH 会解析到 system32\find.exe → 后台 timer 报错、eglot 诊断/补全全空
  (let* ((dir invocation-directory)
         find-exe)
    (while (and dir (not find-exe))
      (let ((candidate (expand-file-name "usr/bin/find.exe" dir))
            (parent (file-name-directory (directory-file-name dir))))
        (if (file-exists-p candidate)
            (setq find-exe candidate)
          (setq dir (unless (equal parent dir) parent)))))
    (when find-exe
      (setq find-program find-exe))))

(provide 'init-windows)
