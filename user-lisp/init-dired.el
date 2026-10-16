;; init-dired.el 	-*- lexical-binding: t -*-
(setq dired-dwim-target t
      dired-auto-revert-buffer #'dired-buffer-stale-p
      dired-recursive-deletes 'always
      dired-recursive-copies 'always
      dired-listing-switches "-alh --group-directories-first")

(with-eval-after-load 'dired
  ;; ⚠ 虚拟 buffer 无真实目录可 revert，须跳过自动 revert
  (define-advice dired-buffer-stale-p (:before-while (&rest args) my/dired-no-revert-in-virtual-a)
    (not (eq revert-buffer-function #'dired-virtual-revert)))

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

(setq dired-compress-file-alist
      '(("\\.7z\\'" . "7z a -r %o %i")
        ("\\.zip\\'" . "7z a -r %o %i"))
      dired-compress-files-alist
      '(("\\.7z\\'" . "7z a -r %o %i")
        ("\\.zip\\'" . "7z a -r %o %i")))

(with-eval-after-load 'image-dired
  (setq image-dired-thumb-size 150)
  (add-to-list 'display-buffer-alist
               '("^\\*image-dired"
                 (display-buffer-in-side-window)
                 (side . bottom)
                 (slot . 20)
                 (window-width . 0.8))))

(provide 'init-dired)
