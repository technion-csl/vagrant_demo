export ROOT_DIR := $(PWD)
SHELL := /bin/bash
.ONESHELL:

##### Global constants #####
VAGRANT := vagrant
BASELINE_VAGRANT_DIR := $(ROOT_DIR)/baseline_vagrant
BASELINE_VAGRANTFILE := $(BASELINE_VAGRANT_DIR)/Vagrantfile
CUSTOM_VAGRANT_DIR := $(ROOT_DIR)/custom_vagrant
LINUX_SOURCE_DIR := $(ROOT_DIR)/linux
LINUX_BUILD_DIR := $(ROOT_DIR)/build
CUSTOM_KERNEL_NAME := custom
KERNEL_VERSION := 5.10.0 # https://github.com/torvalds/linux/releases/tag/v5.10

##### Scripts and commands #####

##### Targets (== files) #####
FLAG := flag
CUSTOM_VAGRANTFILE := $(CUSTOM_VAGRANT_DIR)/Vagrantfile
PROC_CMDLINE := $(BASELINE_VAGRANT_DIR)/proc_cmdline.txt
LINUX_CONFIG_FROM_VAGRANT := $(BASELINE_VAGRANT_DIR)/config_from_vagrant
LINUX_MAKEFILE := $(LINUX_SOURCE_DIR)/Makefile
LINUX_CONFIG := $(LINUX_BUILD_DIR)/.config
VMLINUZ := /boot/vmlinuz-$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)
INITRD := /boot/initrd.img-$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)
PERF_TOOL := /usr/lib/linux-tools/$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)/perf

##### Recipes #####

.PHONY: all clean dist-clean

all: $(FLAG)

$(FLAG): $(CUSTOM_VAGRANTFILE) $(VMLINUZ)
	cd $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT) up --provider=libvirt
	$(VAGRANT) ssh -c "touch $@"
	$(VAGRANT) halt

$(CUSTOM_VAGRANTFILE): $(BASELINE_VAGRANTFILE) $(PROC_CMDLINE)
	mkdir -p $(CUSTOM_VAGRANT_DIR)
	cp -rf $< $@
	proc_cmdline=$$(cat $(PROC_CMDLINE))
	[[ "$$proc_cmdline" =~ (.*)root=(.*) ]]
	root_device=$${BASH_REMATCH[2]}
	sed -i "s,#libvirt.kernel =,libvirt.kernel = \"$(VMLINUZ)\",g" $@
	sed -i "s,#libvirt.initrd =,libvirt.initrd = \"$(INITRD)\",g" $@
	sed -i "s,#libvirt.cmd_line =,libvirt.cmd_line =,g" $@
	sed -i "s,ROOT_DEVICE,$$root_device,g" $@

$(PERF_TOOL): $(LINUX_CONFIG)
	mkdir -p $(LINUX_BUILD_DIR)/tools
	cd $(LINUX_SOURCE_DIR)/tools
	sudo make O=$(LINUX_BUILD_DIR)/tools prefix=/usr perf_install
	# In principle, every linux version requires its own perf, so we have to build it from source.
	# In practice, an older version of perf will usually work, so it's enough to:
	# sudo ln -s /usr/lib/linux-tools/$(uname -r) /usr/lib/linux-tools/$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)

$(VMLINUZ): $(LINUX_CONFIG)
	cd $(LINUX_SOURCE_DIR)
	make -j 8 O=$(LINUX_BUILD_DIR)
	# INSTALL_MOD_STRIP strips the modules and reduces the initrd size by ~10x
	sudo make O=$(LINUX_BUILD_DIR) INSTALL_MOD_STRIP=1 modules_install
	sudo make O=$(LINUX_BUILD_DIR) install

$(LINUX_CONFIG): $(LINUX_CONFIG_FROM_VAGRANT) $(LINUX_MAKEFILE)
	mkdir -p $(LINUX_BUILD_DIR)
	# take the config of the vagrant distribution as the baseline
	cp -f $< $@
	# change dir before calling the config script (it works only from the source dir)
	cd $(LINUX_SOURCE_DIR)
	# edit the config as you wish, e.g., to disable KASLR:
	# ./scripts/config --file $@ --disable RANDOMIZE_BASE
	./scripts/config --file $@ --set-str LOCALVERSION "-$(CUSTOM_KERNEL_NAME)"
	yes '' | make O=$(LINUX_BUILD_DIR) oldconfig # sanitize the .config file

# prevent this target from running concurrently with $(PROC_CMDLINE) by depending on it
$(LINUX_CONFIG_FROM_VAGRANT): $(BASELINE_VAGRANTFILE) $(PROC_CMDLINE)
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT) up --provider=libvirt
	# use bash single quotes to avoid the $(uname -r) expansion in the host
	$(VAGRANT) ssh -c 'cat /boot/config-$$(uname -r)' > $@
	$(VAGRANT) halt
	dos2unix $@

$(PROC_CMDLINE): $(BASELINE_VAGRANTFILE)
	# The Vagrantfile defines the configuration of the VM that resides in the current directory.
	# Fresh Vagrantfiles can be created through: vagrant init generic/ubuntu2004
	# where generic/ubuntu2004 is the box name (all boxes are at: https://app.vagrantup.com/boxes/search)
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT) up --provider=libvirt
	$(VAGRANT) ssh -c "cat /proc/cmdline" > $@
	$(VAGRANT) halt
	dos2unix $@

$(BASELINE_VAGRANTFILE): ; # empty recipe to prevent make from looking for an implicit rule

$(LINUX_MAKEFILE):
	git submodule update --init --progress

clean:
	rm -f $(PROC_CMDLINE) $(LINUX_CONFIG_FROM_VAGRANT)
	cd $(ROOT_DIR)/$(CUSTOM_VAGRANT_DIR)
	# first destroy the VM
	vagrant destroy --force
	# only then, delete the Vagrantfile that defines this VM
	rm -rf $(CUSTOM_VAGRANTFILE)
	rm -rf $(LINUX_BUILD_DIR)
	cd $(LINUX_SOURCE_DIR) && make mrproper

dist-clean: clean
	vagrant box prune --force # remove old versions of installed boxes
	# in case vagrant destroy doesn't work, try deleting the VM manually through virsh:
	# >> virsh list --all
	# >> virsh undefine <NAME>
	sudo ./uninstallKernel.sh $(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)

