;; init-dired.el 	-*- lexical-binding: t -*-
;;
;; 参照 zdn/.emacs.d 简化：不用任何第三方包，纯靠内置 dired/dired-aux/dired-x/image-dired。

(setq dired-dwim-target t
      dired-auto-revert-buffer #'dired-buffer-stale-p
      dired-recursive-deletes 'always
      dired-recursive-copies 'always
      dired-listing-switches "-alh --group-directories-first")

;; 排序（s）、原地展开子目录（i / dired-kill-subdir）都是 dired 内置默认绑定，
;; 不用再自己 define-key。

(with-eval-after-load 'dired
  ;; 不在 dired-virtual buffer 里自动 revert（虚拟 buffer 没有真实目录可 revert）。
  (define-advice dired-buffer-stale-p (:before-while (&rest args) my/dired-no-revert-in-virtual-a)
    (not (eq revert-buffer-function #'dired-virtual-revert)))

  ;; git-ignore 高亮：把被 git 忽略的文件用 dired-ignored 脸色标出来（视觉提示，
  ;; 不是 dired-git-info 那种逐文件 commit 信息，改靠 magit-status 看完整改动）。
  (defun my/dired-vc-ignore-list ()
    (when-let* ((backend (and (vc-root-dir) (vc-responsible-backend default-directory)))
                (ignores (vc-call-backend backend 'ignore-completion-table default-directory)))
      ignores))
  (defun my/dired-vc-font-lock-keywords ()
    (when-let* ((ignores (my/dired-vc-ignore-list)))
      (mapcar (lambda (item)
                `(,dired-move-to-filename-regexp
                  (,(regexp-quote item) (dired-move-to-filename) nil (0 'dired-ignored t))))
              ignores)))
  (defun my/dired-vc-ignores-setup ()
    (when-let* ((keywords (my/dired-vc-font-lock-keywords)))
      (font-lock-add-keywords nil keywords 'add-to-end)))
  (add-hook 'dired-mode-hook #'my/dired-vc-ignores-setup)

  ;; dired-x：omit-files（按 OS 隐藏系统文件）+ 按扩展名关联系统默认程序打开。
  (require 'dired-x)
  (setq dired-omit-files
        (concat "\\`[.]\\|[#~]\\'"
                (cond
                 ((eq system-type 'windows-nt)
                  "\\|^desktop\\.ini$\\|^Thumbs\\.db$\\|^System Volume Information$\\|^\\$RECYCLE\\.BIN$")
                 ((eq system-type 'darwin)
                  "\\|^\\.DS_Store$\\|^\\.localized$\\|^\\._")
                 (t ""))))
  (let ((cmd (cond ((eq system-type 'windows-nt) "start")
                    ((eq system-type 'darwin) "open")
                    ((eq system-type 'gnu/linux) "xdg-open")
                    (t ""))))
    (setq dired-guess-shell-alist-user
          `(("\\.pdf\\'" ,cmd)
            ("\\.docx\\'" ,cmd)
            ("\\.\\(?:jpg\\|jpeg\\|png\\|gif\\|xpm\\|webp\\)\\'" ,cmd)
            ("\\.csv\\'" ,cmd)
            ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|mov\\)\\'" ,cmd)
            ("\\.\\(?:mp3\\|flac\\)\\'" ,cmd)
            ("\\.html?\\'" ,cmd)))))

;; dired-aux：Z/z 压缩解压统一用 7z（需要本机 7z.exe 在 PATH，scoop 装的常见）。
(setq dired-compress-file-alist
      '(("\\.7z\\'" . "7z a -r %o %i")
        ("\\.zip\\'" . "7z a -r %o %i"))
      dired-compress-files-alist
      '(("\\.7z\\'" . "7z a -r %o %i")
        ("\\.zip\\'" . "7z a -r %o %i")))

;; image-dired：缩略图预览开在底部侧边窗口，不占主窗口。
(with-eval-after-load 'image-dired
  (setq image-dired-thumb-size 150)
  (add-to-list 'display-buffer-alist
               '("^\\*image-dired"
                 (display-buffer-in-side-window)
                 (side . bottom)
                 (slot . 20)
                 (window-width . 0.8))))

(provide 'init-dired)
