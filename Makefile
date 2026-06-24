EMACS ?= emacs
ROOT := $(CURDIR)
DUMP := $(ROOT)/emacs.pdmp

# Compile all local config .el files, excluding third-party packages.
EL_FILES := $(shell find "$(ROOT)" -type f -name "*.el" \
	-not -path "$(ROOT)/elpa/*" \
	-not -path "$(ROOT)/.git/*")

.PHONY: all dump compile clean

# 默认构建：生成自定义 portable dump（emacs.pdmp），用 --dump-file 启动可大幅加速。
all: dump

# 预加载重包并转储成 emacs.pdmp（脚本见 dump.el）。
# 启动：emacs --dump-file=$(DUMP)  或用 emacs-dump.cmd。
# 注意：装/删包或升级 emacs（scoop 更新）后必须重跑 `make dump`，否则映像不兼容。
dump:
	@echo "Building portable dump -> emacs.pdmp ..."
	@$(EMACS) --batch -Q -l "$(ROOT)/dump.el"

# 字节编译作语法检查（非默认；产物 .elc 仅供检查，别留在工作区，见 /build）。
compile:
	@echo "Compiling Emacs Lisp files to .elc..."
	@$(EMACS) --batch -Q \
		--eval "(setq user-emacs-directory (file-name-as-directory \"$(ROOT)\"))" \
		--eval "(add-to-list 'load-path (expand-file-name \"lisp\" user-emacs-directory))" \
		--eval "(setq package-user-dir (expand-file-name \"elpa\" user-emacs-directory))" \
		--eval "(require 'package)" \
		--eval "(package-initialize)" \
		--eval "(byte-recompile-directory user-emacs-directory 0)" \
		--eval "(message \"Byte compilation finished\")"

# 删除生成物（.elc 与 emacs.pdmp）。
# 注意：find 为 GNU 语法，在 Windows 会命中 system32\find.exe 而失效；
# Windows 下清理改用 PowerShell（见 /build 与 AGENTS.md）。
clean:
	@echo "Removing generated .elc and emacs.pdmp ..."
	@find "$(ROOT)" -type f -name "*.elc" \
		-not -path "$(ROOT)/elpa/*" \
		-delete
	@rm -f "$(DUMP)"
