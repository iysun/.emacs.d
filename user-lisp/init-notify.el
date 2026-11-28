;;; init-notify.el --- 启用 iys-notify  -*- lexical-binding: t; -*-

(require 'iys-notify)

(defalias 'iys/doc-at-point #'iys-notify-doc-at-point)
(add-to-list 'iys-notify-persist-commands 'iys/doc-at-point)
(add-to-list 'iys-notify-persist-commands 'iys-notify-copy-dwim)

(unless noninteractive
  (iys-notify-mode 1))

(provide 'init-notify)
