;; init-project.el 	-*- lexical-binding: t -*-

;; 内置 project.el（Emacs 28+）：`C-c p` 与默认的 `C-x p` 相同前缀命令
(require 'project)

(defun my/find-project-root (&optional directory)
  "解析当前缓冲区的项目根目录，与 `project.el` 一致；若无项目则使用当前目录。"
  (let* ((dir (or directory default-directory))
         (default-directory dir))
    (or (when-let* ((proj (project-current nil)))
          (project-root proj))
        dir)))

(defun my/set-custom-root-as-default-directory ()
  "将当前 buffer 的 default-directory 设置为自定义项目根目录。"
  (interactive)
  (setq-local default-directory (my/find-project-root)))

(add-hook 'find-file-hook #'my/set-custom-root-as-default-directory)

(provide 'init-project)
