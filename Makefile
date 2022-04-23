

.DEFAULT_GOAL      := release

# echo_cmd is silent in verbose mode, makes sense
ifeq ($(V),1)
echo_cmd=@:
Q=
else
echo_cmd=@echo
Q=@
endif

ifndef BUILD_DIR
BUILD_DIR := build/release-wasm-js
endif
ifeq ($(BUILD_DIR),)
BUILD_DIR := build/release-wasm-js
endif
ifndef COMPILE_PLATFORM
COMPILE_PLATFORM   := $(shell uname | sed -e 's/_.*//' | tr '[:upper:]' '[:lower:]' | sed -e 's/\//_/g')
endif

MKDIR              := mkdir -p
LD                 := libs/$(COMPILE_PLATFORM)/wasi-sdk-14.0/bin/wasm-ld
CC                 := libs/$(COMPILE_PLATFORM)/wasi-sdk-14.0/bin/clang
CXX                := libs/$(COMPILE_PLATFORM)/wasi-sdk-14.0/bin/clang++


WASI_INCLUDES    := \
	-Ilibs/wasi-sysroot/include \
	-I$(SDL_SOURCE)/include 

BASE_CFLAGS        := \
	$(CFLAGS) -Wall --target=wasm32 \
	-Wimplicit -fstrict-aliasing \
	-ftree-vectorize -fsigned-char -MMD \
	-ffast-math -fno-short-enums  -fPIC \
	-D_XOPEN_SOURCE=700 \
	-D__EMSCRIPTEN__=1 \
	-D__WASM__=1 \
	-D__wasi__=1 \
	-D__wasm32__=1 \
	-D_WASI_EMULATED_SIGNAL \
	-D_WASI_EMULATED_MMAN=1 \
	-std=gnu11

CLIENT_CFLAGS      := $(BASE_CFLAGS) \
											$(WASI_INCLUDES)

WASI_SYSROOT       := libs/wasi-sysroot/lib/wasm32-wasi
WASI_LDFLAGS       := $(LDFLAGS) \
	-Wl,--import-memory -Wl,--import-table \
	-Wl,--export-dynamic -Wl,--error-limit=200 \
	-Wl,--export=sprintf -Wl,--export=malloc  \
	-Wl,--export=stderr -Wl,--export=stdout  \
	-Wl,--export=errno --no-standard-libraries \
	-Wl,--allow-undefined-file=engine/wasm/wasm.syms \
	engine/wasm/wasi/libclang_rt.builtins-wasm32.a \
	$(WASI_SYSROOT)/libc.a

CLIENT_LDFLAGS     := $(WASI_LDFLAGS) -Wl,--no-entry 
	

# WRITE THIS IN A WAY THAT THE FILE TREE
#   CAN PARSE IT AND SHOW A SWEET LITTLE GRAPH
#   OF COMMANDS THAT RUN FOR EACH FILE TO COMPILE.
GAME_SOURCE   := games/lobby
UIVM_SOURCE   := $(GAME_SOURCE)/q3_ui
GAME_SOURCE   := $(GAME_SOURCE)/game
Q3ASM_SOURCE  := libs/q3asm
Q3RCC_SOURCE  := libs/q3lcc/src
LBURG_SOURCE  := libs/q3lcc/lburg
Q3CPP_SOURCE  := libs/q3lcc/cpp
Q3LCC_SOURCE  := libs/q3lcc/etc


# LAYOUT BUILD_DIRS UPFRONT
BUILD_DIRS    := \
	$(BUILD_DIR).mkdir \
	$(filter $(MAKECMDGOALS),clean) \
	$(BUILD_DIR).mkdir/q3asm/ \
	$(BUILD_DIR).mkdir/q3lcc/ \
	$(BUILD_DIR).mkdir/q3rcc/ \
	$(BUILD_DIR).mkdir/q3cpp/ \
	$(BUILD_DIR).mkdir/lburg/ \
	$(BUILD_DIR).mkdir/uivm/ \


define MKDIR_SH
	@if [ ! -d "./$1" ]; \
		then $(MKDIR) "./$1";fi;
endef

$(BUILD_DIR).mkdir/%/:
	$(call MKDIR_SH,$(subst .mkdir,,$@))

$(BUILD_DIR).mkdir/:
	$(call MKDIR_SH,$(subst .mkdir,,$@))

#D_DIRS  := $(addprefix $(BUILD_DIR)/,$(WORKDIRS))
D_FILES := $(shell find $(BUILD_DIR)/** -name '*.d' 2>/dev/null)
ifneq ($(strip $(D_FILES)),)
include $(D_FILES)
endif

release: 
	$(Q)$(MAKE) multigame engine \
		plugin index build-tools deploy \
		BUILD_DIR="build/release-wasm-js" \
		CFLAGS="$(RELEASE_CFLAGS)" \
		LDFLAGS="$(RELEASE_LDFLAGS)"

debug: 
	$(Q)$(MAKE) multigame engine \
		plugin index build-tools deploy \
		BUILD_DIR="build/debug-wasm-js" \
		CFLAGS="$(DEBUG_CFLAGS)" \
		LDFLAGS="$(DEBUG_LDFLAGS)"

multigame: q3asm.wasm q3lcc.wasm ui.qvm cgame.qvm qagame.qvm



Q3LCC_CFLAGS     := $(CLIENT_CFLAGS) \
	-Wno-logical-op-parentheses \
	-Wno-unused-variable \
	-Wno-misleading-indentation \
	-Wno-unused-label \
	-Wno-parentheses \
	-Wno-dangling-else \
	-Wno-missing-braces \
	-Wno-parentheses




# MAKE Q3LCC-WASM TO RECOMPILE GAME CODE IN BROWSER-WORKER
Q3ASM_FILES  := $(wildcard $(Q3ASM_SOURCE)/*.c)
Q3ASM_OBJS   := $(subst libs/,$(BUILD_DIR)/,$(Q3ASM_FILES:.c=.o))

define DO_Q3ASM_CC
	$(echo_cmd) "Q3ASM_CC $<"
	$(Q)$(CC) -o $@ $(Q3LCC_CFLAGS) -c $<
endef

define DO_WASM_LD
	$(echo_cmd) "WASM-LD $1"
	$(Q)$(CC) -o $(BUILD_DIR)/$1 $2 $(CLIENT_LDFLAGS)
endef




define DO_CLI_LD
	$(echo_cmd) "WASM-LD $1"
	$(Q)$(CC) -o $(BUILD_DIR)/$1 $2 $(WASI_LDFLAGS)
endef

q3asm.wasm: $(BUILD_DIRS) $(Q3ASM_FILES) $(Q3ASM_OBJS)
	$(call DO_CLI_LD,$@,$(Q3ASM_OBJS))

$(BUILD_DIR)/q3asm/%.o: $(Q3ASM_SOURCE)/%.c
	$(DO_Q3ASM_CC)



define DO_CLIEXE_LD
	$(echo_cmd) "WASM-LD $1"
	$(Q)$(CC) -o $(BUILD_DIR)/$1 \
		$(WASI_SYSROOT)/libwasi-emulated-signal.a \
		$(WASI_SYSROOT)/libwasi-emulated-getpid.a \
		$2 $(WASI_LDFLAGS)
endef

define DO_Q3LCC_CC
	$(echo_cmd) "Q3LCC_CC $<"
	$(Q)$(CC) -o $@ $(Q3LCC_CFLAGS) -c $<
endef

Q3LCC_FILES  := $(wildcard $(Q3LCC_SOURCE)/*.c)
Q3LCC_OBJS   := $(subst $(Q3LCC_SOURCE)/,$(BUILD_DIR)/q3lcc/,$(Q3LCC_FILES:.c=.o))

q3lcc.wasm: q3rcc.wasm q3cpp.wasm $(Q3LCC_FILES) $(Q3LCC_OBJS)
	$(call DO_CLIEXE_LD,$@,$(Q3LCC_OBJS))

$(BUILD_DIR)/q3lcc/%.o: $(Q3LCC_SOURCE)/%.c
	$(DO_Q3LCC_CC)






define DO_LBURG_CC
	$(echo_cmd) "LBURG_CC $<"
	$(Q)$(CC) -o $@ $(Q3LCC_CFLAGS) -c $<
endef

LBURG_FILES  := $(wildcard $(LBURG_SOURCE)/*.c)
LBURG_OBJS  := $(subst $(LBURG_SOURCE)/,$(BUILD_DIR)/lburg/,$(LBURG_FILES:.c=.o))

lburg.wasm: $(BUILD_DIRS) $(LBURG_FILES) $(LBURG_OBJS)
	$(call DO_CLI_LD,$@,$(LBURG_OBJS))

$(BUILD_DIR)/lburg/%.o: $(LBURG_SOURCE)/%.c
	$(DO_LBURG_CC)

$(BUILD_DIR)/q3rcc/dagcheck.c: lburg.wasm $(Q3RCC_SOURCE)/dagcheck.md
	$(Q)node ./engine/wasm/bin/wasm-cli.js -- \
			lburg.wasm $(Q3RCC_SOURCE)/dagcheck.md $@ 


Q3RCC_CFLAGS := $(Q3LCC_CFLAGS) -I$(Q3RCC_SOURCE)

define DO_Q3RCC_CC
	$(echo_cmd) "Q3RCC_CC $<"
	$(Q)$(CC) -o $@ $(Q3RCC_CFLAGS) -c $<
endef

Q3RCC_FILES  := $(filter-out %/dagcheck.c,$(wildcard $(Q3RCC_SOURCE)/*.c))
DAGCHK_FILES := $(Q3RCC_SOURCE)/dagcheck.md \
								$(BUILD_DIR)/q3rcc/dagcheck.c
Q3RCC_OBJS   := $(subst $(Q3RCC_SOURCE)/,$(BUILD_DIR)/q3rcc/,$(Q3RCC_FILES:.c=.o)) \
								$(BUILD_DIR)/q3rcc/dagcheck.o
# WTF IS DAGCHECK.C?
q3rcc.wasm: lburg.wasm $(BUILD_DIRS) $(DAGCHK_FILES) \
						$(Q3RCC_FILES) $(Q3RCC_OBJS)
	$(call DO_CLI_LD,$@,$(Q3RCC_OBJS))

$(BUILD_DIR)/q3rcc/%.o: $(Q3RCC_SOURCE)/%.c
	$(DO_Q3RCC_CC)

$(BUILD_DIR)/q3rcc/dagcheck.o: \
	$(BUILD_DIR)/q3rcc/dagcheck.c
	$(DO_Q3RCC_CC)



define DO_Q3CPP_CC
	$(echo_cmd) "Q3CPP_CC $<"
	$(Q)$(CC) -o $@ $(Q3RCC_CFLAGS) -c $<
endef

Q3CPP_FILES  := $(wildcard $(Q3CPP_SOURCE)/*.c)
Q3CPP_OBJS   := $(subst $(Q3CPP_SOURCE)/,$(BUILD_DIR)/q3cpp/,$(Q3CPP_FILES:.c=.o))

q3cpp.wasm: $(BUILD_DIRS) $(Q3CPP_FILES) $(Q3CPP_OBJS)
	$(call DO_CLI_LD,$@,$(Q3CPP_OBJS))

$(BUILD_DIR)/q3cpp/%.o: $(Q3CPP_SOURCE)/%.c
	$(DO_Q3CPP_CC)



WASM_ASM := $(Q)node ./engine/wasm/bin/wasm-cli.js -- \
			q3asm.wasm 
WASM_LCC := $(Q)node  ./engine/wasm/bin/wasm-cli.js -- \
			q3lcc.wasm 

define DO_UIVM_CC
	$(echo_cmd) "UIVM_CC $<"
	$(Q)$(WASM_LCC) -DUI -o $@ -c $<
endef

UIVM_FILES  := $(wildcard $(UIVM_SOURCE)/*.c)
UI_SHARED   := \
	$(UIVM_SOURCE)/../game/bg_lib.c \
	$(UIVM_SOURCE)/../game/bg_misc.c \
	$(UIVM_SOURCE)/../game/q_math.c \
	$(UIVM_SOURCE)/../game/q_shared.c

UIVM_OBJS := $(subst $(UIVM_SOURCE)/,$(BUILD_DIR)/uivm/,$(UIVM_FILES:.c=.asm)) \
	$(BUILD_DIR)/uivm/bg_lib.asm \
	$(BUILD_DIR)/uivm/bg_misc.asm \
	$(BUILD_DIR)/uivm/q_math.asm \
	$(BUILD_DIR)/uivm/q_shared.asm \
	$(UIVM_SOURCE)/../game/ui_syscalls.asm

ui.qvm: $(BUILD_DIRS) $(UI_SHARED) $(UIVM_FILES) $(UIVM_OBJS)
	$(echo_cmd) "Q3ASM $@"
	$(Q)$(WASM_ASM) -o $@ -m $(UIVM_OBJS)

$(BUILD_DIR)/uivm/%.asm: $(UIVM_SOURCE)/%.c
	$(DO_UIVM_CC)

$(BUILD_DIR)/uivm/%.asm: $(GAMEVM_SOURCE)/%.c
	$(DO_UIVM_CC)







