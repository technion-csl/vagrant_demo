##### Constants #####

QEMU_SOURCE_DIR := $(ROOT_DIR)/qemu/source
QEMU_BUILD_DIR := $(ROOT_DIR)/qemu/build
QEMU_OFFICIAL_GIT_REPO := https://gitlab.com/qemu-project/qemu.git

##### Targets (== files) #####

QEMU_CONFIGURE := $(QEMU_SOURCE_DIR)/configure
QEMU_MAKEFILE := $(QEMU_BUILD_DIR)/Makefile
QEMU_EXECUTABLE := $(QEMU_BUILD_DIR)/x86_64-softmmu/qemu-system-x86_64

##### Recipes #####

.PHONY: qemu qemu/clean qemu/fetch-upstream

qemu: $(QEMU_EXECUTABLE)

$(QEMU_EXECUTABLE): $(QEMU_MAKEFILE)
	cd $(QEMU_BUILD_DIR)
	make --jobs=$$(nproc)

$(QEMU_MAKEFILE): $(QEMU_CONFIGURE) | $(QEMU_BUILD_DIR) $(qemu_prerequisites) $(kernel_prerequisites)
	cd $(QEMU_BUILD_DIR)
	$< --target-list=x86_64-softmmu
	touch $@

$(QEMU_CONFIGURE):
	$(GIT_SUBMODULE_UPDATE) qemu/source

# create the required directory when we need it
$(QEMU_BUILD_DIR):
	mkdir -p $@

qemu/clean:
	rm -rf $(QEMU_BUILD_DIR)

qemu/fetch-upstream:
	cd $(QEMU_SOURCE_DIR)
	if [[ $$(git remote | grep upstream) == "" ]] ; then
		git remote add upstream $(QEMU_OFFICIAL_GIT_REPO)
	fi
	$(FETCH_UPSTREAM)

