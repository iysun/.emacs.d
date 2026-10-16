;; -*- lexical-binding: t; -*-

(when (executable-find "readtags")
  (use-package citre :ensure t :defer t)
  ;; ⚠ *scratch* 属 prog-mode，须守卫 buffer-file-name
  (add-hook 'prog-mode-hook
            (lambda () (when (buffer-file-name) (citre-mode 1))))
  (with-eval-after-load 'citre
    (setq citre-auto-enable-citre-mode nil)))

(provide 'init-navigation)
