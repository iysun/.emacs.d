;; -*- lexical-binding: t; -*-

(when (executable-find "readtags")
  ;; ⚠ *scratch* 属 prog-mode，须守卫 buffer-file-name
  (add-hook 'prog-mode-hook
            (lambda () (when (buffer-file-name) (citre-mode 1)))))

(provide 'init-navigation)
