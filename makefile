SHELL := /bin/bash
# run all lines of a recipe in a single invocation of the shell rather than each line being invoked separately
.ONESHELL:
# invoke recipes as if the shell had been passed the -e flag: the first failing command in a recipe will cause the recipe to fail immediately
.POSIX:

##### Global constants #####

export ROOT_DIR=$(PWD)
# don't modify this variable because we rely on identical paths in the guest and host
export SHARED_VAGRANT_DIR=$(ROOT_DIR)
# change the directory where Vagrant stores global state because it is set to ~/.vagrant.d by default,
# and this causes conflicts between servers as the ~ directory is mounted on NFS.
export VAGRANT_HOME=$(ROOT_DIR)/.vagrant.d
export APT_INSTALL=sudo apt install -y
export APT_REMOVE=sudo apt purge -y

##### Targets (== files) #####

# the following list should preserve a topological ordering, i.e., if module B
# uses variables defined in module A, than module A should come before module B
SUBMODULES := libvirt vagrant vanilla_vm linux qemu custom_vm
FLAG := $(ROOT_DIR)/flag

##### Recipes #####

.PHONY: all clean
all: $(FLAG)

$(FLAG): $(SUBMODULES)
	cd $(CUSTOM_VM_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) ssh -c "cd $(SHARED_VAGRANT_DIR) && make linux/prerequisites"
	$(VAGRANT) ssh -c "sudo mkdir -p $(dir $(INSTALLED_PERF_TOOL)) && sudo cp -f $(PERF_TOOL) $(INSTALLED_PERF_TOOL)"
	$(VAGRANT) ssh -c "uname -a && perf --version" > $@
	$(VAGRANT_HALT)

# ignore errors when executing these two recipes (the VMs may not exist so deleting them may fail)
#.IGNORE: clean-baseline-vagrant clean-custom-vagrant

clean: $(addsuffix /clean,$(SUBMODULES))
	rm -rf $(FLAG)

-include $(patsubst %,%/module.mk,$(SUBMODULES))

