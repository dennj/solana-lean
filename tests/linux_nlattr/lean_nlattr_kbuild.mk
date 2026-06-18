# SPDX-License-Identifier: GPL-2.0

obj-$(CONFIG_NLATTR) += lean_nlattr_hook.o lean_nlattr_core.o

LEAN_NLATTR_TRIPLE ?= riscv64-unknown-none-elf
LEAN_NLATTR_HEAP_BYTES ?= 65536
LEAN_NLATTR_LEAN ?= lean
LEAN_NLATTR_CLANG ?= $(CC)
LEAN_NLATTR_LD ?= $(LD)
LEAN_NLATTR_OBJCOPY ?= $(OBJCOPY)
LEAN_NLATTR_LLVM_LINK ?= llvm-link-19

lean_nlattr_core_dir := $(srctree)/lib/lean_nlattr_core
lean_nlattr_build_dir := $(obj)/lean_nlattr_core.build
lean_nlattr_bc := $(lean_nlattr_build_dir)/NlAttrCore.bc
lean_nlattr_memory_bc := $(lean_nlattr_build_dir)/NlAttrMemory.bc
lean_nlattr_memory_olean := $(lean_nlattr_build_dir)/NlAttrMemory.olean
lean_nlattr_raw_bc := $(lean_nlattr_build_dir)/nlattr_raw.bc
lean_nlattr_runtime_bc := $(lean_nlattr_build_dir)/runtime.bc
lean_nlattr_linked_bc := $(lean_nlattr_build_dir)/NlAttrCore.linked.bc
lean_nlattr_olean := $(lean_nlattr_build_dir)/NlAttrCore.olean
lean_nlattr_lean_o := $(lean_nlattr_build_dir)/NlAttrCore.o
lean_nlattr_kernel_abi_o := $(lean_nlattr_build_dir)/lean_nlattr_core.kernel-abi.o
lean_nlattr_prepare := $(shell mkdir -p $(lean_nlattr_build_dir))

lean_nlattr_public_roots := \
	-u lean_public___nla_validate \
	-u lean_public___nla_parse \
	-u nla_get_range_unsigned \
	-u nla_get_range_signed \
	-u nla_policy_len \
	-u nla_find \
	-u nla_strscpy \
	-u nla_strdup \
	-u nla_memcpy \
	-u nla_memcmp \
	-u nla_strcmp \
	-u lean_public___nla_reserve \
	-u lean_public___nla_reserve_64bit \
	-u lean_public___nla_reserve_nohdr \
	-u nla_reserve \
	-u nla_reserve_64bit \
	-u nla_reserve_nohdr \
	-u lean_public___nla_put \
	-u lean_public___nla_put_64bit \
	-u lean_public___nla_put_nohdr \
	-u nla_put \
	-u nla_put_64bit \
	-u nla_put_nohdr \
	-u nla_append

targets += lean_nlattr_core.o
targets += lean_nlattr_core.build/NlAttrMemory.olean
targets += lean_nlattr_core.build/NlAttrMemory.bc
targets += lean_nlattr_core.build/NlAttrCore.bc
targets += lean_nlattr_core.build/nlattr_raw.bc
targets += lean_nlattr_core.build/runtime.bc
targets += lean_nlattr_core.build/NlAttrCore.linked.bc
targets += lean_nlattr_core.build/NlAttrCore.o
targets += lean_nlattr_core.build/lean_nlattr_core.kernel-abi.o
clean-files += lean_nlattr_core.build

lean_nlattr_common_flags := \
	--target=$(LEAN_NLATTR_TRIPLE) \
	-O2 \
	-ffreestanding \
	-fno-stack-protector \
	-fno-builtin \
	-fno-pic \
	-ffunction-sections \
	-fdata-sections \
	-mcmodel=medany \
	-mno-relax \
	-msmall-data-limit=0 \
	-march=rv64imac \
	-mabi=lp64

$(lean_nlattr_build_dir):
	$(Q)mkdir -p $@

quiet_cmd_lean_nlattr_memory = LEANMEM $@
cmd_lean_nlattr_memory = mkdir -p $(dir $@) && (cd $(lean_nlattr_core_dir) && \
		$(LEAN_NLATTR_LEAN) --target=$(LEAN_NLATTR_TRIPLE) --root=. \
		--bc=$(abspath $(lean_nlattr_memory_bc)) \
		-o $(abspath $(lean_nlattr_memory_olean)) NlAttrMemory.lean)

$(lean_nlattr_memory_olean) $(lean_nlattr_memory_bc): $(lean_nlattr_core_dir)/NlAttrMemory.lean FORCE | $(lean_nlattr_build_dir)
	$(call if_changed,lean_nlattr_memory)

quiet_cmd_lean_nlattr_bc = LEANBC  $@
cmd_lean_nlattr_bc = mkdir -p $(dir $@) && (cd $(lean_nlattr_core_dir) && \
		LEAN_PATH=$(abspath $(lean_nlattr_build_dir)) \
		$(LEAN_NLATTR_LEAN) --target=$(LEAN_NLATTR_TRIPLE) --root=. \
		--bc=$(abspath $(lean_nlattr_bc)) \
		-o $(abspath $(lean_nlattr_olean)) NlAttrCore.lean)

$(lean_nlattr_bc): $(lean_nlattr_core_dir)/NlAttrCore.lean $(lean_nlattr_memory_olean) FORCE | $(lean_nlattr_build_dir)
	$(call if_changed,lean_nlattr_bc)

quiet_cmd_lean_nlattr_raw_bc = RAWBC   $@
cmd_lean_nlattr_raw_bc = mkdir -p $(dir $@) && \
		$(LEAN_NLATTR_CLANG) $(lean_nlattr_common_flags) -emit-llvm \
		-c $(lean_nlattr_core_dir)/nlattr_raw.c -o $@

$(lean_nlattr_raw_bc): $(lean_nlattr_core_dir)/nlattr_raw.c FORCE | $(lean_nlattr_build_dir)
	$(call if_changed,lean_nlattr_raw_bc)

quiet_cmd_lean_nlattr_runtime_bc = RUNTBC  $@
cmd_lean_nlattr_runtime_bc = mkdir -p $(dir $@) && \
		$(LEAN_NLATTR_CLANG) $(lean_nlattr_common_flags) -emit-llvm \
		-I$(lean_nlattr_core_dir) \
		-DLEAN_FREESTANDING_HEAP_SYMBOLS \
		-DLEAN_FREESTANDING_RECLAIMING_RC \
		-DLEAN_FREESTANDING_HEAP_BYTES=$(LEAN_NLATTR_HEAP_BYTES) \
		-c $(lean_nlattr_core_dir)/runtime.c -o $@

$(lean_nlattr_runtime_bc): $(lean_nlattr_core_dir)/runtime.c $(lean_nlattr_core_dir)/lean_freestanding.h FORCE | $(lean_nlattr_build_dir)
	$(call if_changed,lean_nlattr_runtime_bc)

quiet_cmd_lean_nlattr_link_bc = LLVMLNK $@
cmd_lean_nlattr_link_bc = mkdir -p $(dir $@) && \
		$(LEAN_NLATTR_LLVM_LINK) $(abspath $(lean_nlattr_bc)) \
		$(abspath $(lean_nlattr_memory_bc)) \
		$(abspath $(lean_nlattr_raw_bc)) \
		$(abspath $(lean_nlattr_runtime_bc)) -o $@

$(lean_nlattr_linked_bc): $(lean_nlattr_bc) $(lean_nlattr_memory_bc) $(lean_nlattr_raw_bc) $(lean_nlattr_runtime_bc) FORCE
	$(call if_changed,lean_nlattr_link_bc)

quiet_cmd_lean_nlattr_lean_o = LEANCC  $@
cmd_lean_nlattr_lean_o = mkdir -p $(dir $@) && \
		$(LEAN_NLATTR_CLANG) $(lean_nlattr_common_flags) -c $< -o $@

$(lean_nlattr_lean_o): $(lean_nlattr_linked_bc) FORCE
	$(call if_changed,lean_nlattr_lean_o)

quiet_cmd_lean_nlattr_link = LEANLD  $@
cmd_lean_nlattr_link = $(LEAN_NLATTR_LD) -r --gc-sections \
	$(lean_nlattr_public_roots) \
	$(lean_nlattr_lean_o) -o $@

$(lean_nlattr_kernel_abi_o): $(lean_nlattr_lean_o) FORCE
	$(call if_changed,lean_nlattr_link)

quiet_cmd_lean_nlattr_abi = LEANABI $@
cmd_lean_nlattr_abi = $(LEAN_NLATTR_OBJCOPY) \
	--redefine-sym lean_public___nla_validate=__nla_validate \
	--redefine-sym lean_public___nla_parse=__nla_parse \
	--redefine-sym lean_public___nla_reserve=__nla_reserve \
	--redefine-sym lean_public___nla_reserve_64bit=__nla_reserve_64bit \
	--redefine-sym lean_public___nla_reserve_nohdr=__nla_reserve_nohdr \
	--redefine-sym lean_public___nla_put=__nla_put \
	--redefine-sym lean_public___nla_put_64bit=__nla_put_64bit \
	--redefine-sym lean_public___nla_put_nohdr=__nla_put_nohdr \
	$< $@

$(obj)/lean_nlattr_core.o: $(lean_nlattr_kernel_abi_o) FORCE
	$(call if_changed,lean_nlattr_abi)
