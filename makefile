SHELL := /bin/bash
# run all lines of a recipe in a single invocation of the shell rather than each line being invoked separately
.ONESHELL:
# invoke recipes as if the shell had been passed the -e flag: the first failing command in a recipe will cause the recipe to fail immediately
.POSIX:

# the following list should preserve a topological ordering, i.e., if module B
# uses variables defined in module A, than module A should come before module B
SUBMODULES := libvirt vagrant linux qemu

.PHONY: all clean
all: $(SUBMODULES)
clean: $(addsuffix /clean,$(SUBMODULES))

-include $(patsubst %,%/module.mk,$(SUBMODULES))

##### Global constants #####

export ROOT_DIR := $(PWD)
# don't modify this variable because we rely on identical paths in the guest and host
export SHARED_VAGRANT_DIR := $(ROOT_DIR)
CUSTOM_VAGRANT_NAME := custom_vagrant
CUSTOM_VAGRANT_DIR := $(ROOT_DIR)/$(CUSTOM_VAGRANT_NAME)
# change the directory where Vagrant stores global state because it is set to ~/.vagrant.d by default,
# and this causes conflicts between servers as the ~ directory is mounted on NFS.
export VAGRANT_HOME := $(ROOT_DIR)/.vagrant.d

##### Scripts and commands #####

APT_INSTALL := sudo apt install -y
APT_REMOVE := sudo apt purge -y
VAGRANT := vagrant
VAGRANT_UP := $(VAGRANT) up --provider=libvirt
VAGRANT_HALT := $(VAGRANT) halt || $(VAGRANT) halt --force
VAGRANT_DESTROY := $(VAGRANT) destroy --force
# more about the plugin: https://github.com/vagrant-libvirt/vagrant-libvirt

##### Targets (== files) #####

CUSTOM_VAGRANTFILE := $(CUSTOM_VAGRANT_DIR)/Vagrantfile
FLAG := $(ROOT_DIR)/flag

##### Recipes #####

all: $(FLAG)

$(FLAG): $(CUSTOM_VAGRANTFILE) $(VMLINUZ) $(INITRD) $(PERF_TOOL) $(QEMU_EXECUTABLE)
	cd $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) ssh -c "cd $(SHARED_VAGRANT_DIR) && make linux-prerequisites"
	$(VAGRANT) ssh -c "sudo mkdir -p $(dir $(INSTALLED_PERF_TOOL)) && sudo cp -f $(PERF_TOOL) $(INSTALLED_PERF_TOOL)"
	$(VAGRANT) ssh -c "uname -a && perf --version" > $@
	$(VAGRANT_HALT)

# ignore errors when executing these two recipes (the VMs may not exist so deleting them may fail)
#.IGNORE: clean-baseline-vagrant clean-custom-vagrant

clean:
	rm -rf $(FLAG)
	$(VAGRANT) box prune --force # remove old versions of installed boxes

