export ROOT_DIR := $(PWD)
SHELL := /bin/bash
# run all lines of a recipe in a single invocation of the shell rather than each line being invoked separately
.ONESHELL:
# invoke recipes as if the shell had been passed the -e flag: the first failing command in a recipe will cause the recipe to fail immediately
.POSIX:

##### Global constants #####
BASELINE_VAGRANT_NAME := baseline_vagrant
BASELINE_VAGRANT_DIR := $(ROOT_DIR)/$(BASELINE_VAGRANT_NAME)
BASELINE_VAGRANTFILE := $(BASELINE_VAGRANT_DIR)/Vagrantfile
CUSTOM_VAGRANT_NAME := custom_vagrant
CUSTOM_VAGRANT_DIR := $(ROOT_DIR)/$(CUSTOM_VAGRANT_NAME)
# change the directory where Vagrant stores global state because it is set to ~/.vagrant.d by default,
# and this causes conflicts between servers as the ~ directory is mounted on NFS.
export VAGRANT_HOME := $(ROOT_DIR)/.vagrant.d
LINUX_SOURCE_DIR := $(ROOT_DIR)/linux
LINUX_BUILD_DIR := $(ROOT_DIR)/build
CUSTOM_KERNEL_NAME := custom
# choose a specific linux kernel version with "cd linux && git checkout tags/v5.4"
KERNEL_VERSION := 5.4.109
# we can also extract the kernel version from the linux source tree via "cd linux && make kernelversion"
# but this is problematic because $(LINUX_SOURCE_DIR) is empty right after "git clone"

##### Scripts and commands #####
APT_INSTALL := sudo apt install -y
APT_REMOVE := sudo apt purge -y
VAGRANT := vagrant
# more about the plugin: https://github.com/vagrant-libvirt/vagrant-libvirt
VAGRANT_PLUGIN := vagrant-libvirt

##### Targets (== files) #####
FLAG := $(ROOT_DIR)/flag
CUSTOM_VAGRANTFILE := $(CUSTOM_VAGRANT_DIR)/Vagrantfile
PROC_CMDLINE := $(BASELINE_VAGRANT_DIR)/proc_cmdline.txt
BASELINE_LINUX_CONFIG := $(BASELINE_VAGRANT_DIR)/config_from_vagrant
LINUX_MAKEFILE := $(LINUX_SOURCE_DIR)/Makefile
LINUX_CONFIG := $(LINUX_BUILD_DIR)/.config
VMLINUZ := /boot/vmlinuz-$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)
INITRD := /boot/initrd.img-$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)
PERF_TOOL := $(LINUX_BUILD_DIR)/tools/perf/perf
INSTALLED_PERF_TOOL := /usr/lib/linux-tools/$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)/perf

##### Recipes #####

.PHONY: all ssh-baseline-vagrant ssh-custom-vagrant prerequisites \
	clean clean-baseline clean-custom dist-clean

all: $(FLAG)

$(FLAG): $(CUSTOM_VAGRANTFILE) $(VMLINUZ) $(INSTALLED_PERF_TOOL)
	cd $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT) up --provider=libvirt
	$(VAGRANT) ssh -c "make -C $(LINUX_SOURCE_DIR)/tools/perf O=$(LINUX_BUILD_DIR)/tools/perf prefix=/usr/ install"
	$(VAGRANT) ssh -c "uname -a && perf --version" > $@
	$(VAGRANT) halt

$(INSTALLED_PERF_TOOL): $(PERF_TOOL)
	sudo make -C $(LINUX_SOURCE_DIR)/tools/perf O=$(LINUX_BUILD_DIR)/tools/perf prefix=/usr install
	# In principle, every linux version requires its own perf, so we have to build it from source.
	# In practice, an older version of perf will usually work, so it's enough to:
	# sudo ln -s /usr/lib/linux-tools/$(uname -r) /usr/lib/linux-tools/$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)

$(PERF_TOOL): $(LINUX_CONFIG)
	mkdir -p $(dir $@)
	make -C $(LINUX_SOURCE_DIR)/tools/perf O=$(LINUX_BUILD_DIR)/tools/perf JOBS=8

$(VMLINUZ): $(LINUX_CONFIG)
	cd $(LINUX_SOURCE_DIR)
	make --jobs=8 O=$(LINUX_BUILD_DIR)
	# INSTALL_MOD_STRIP strips the modules and reduces the initrd size by ~10x
	sudo make O=$(LINUX_BUILD_DIR) INSTALL_MOD_STRIP=1 modules_install
	sudo make O=$(LINUX_BUILD_DIR) install

$(LINUX_CONFIG): $(BASELINE_LINUX_CONFIG) $(LINUX_MAKEFILE)
	mkdir -p $(LINUX_BUILD_DIR)
	# take the config of the vagrant distribution as the baseline
	cp -f $< $@
	# change dir before calling the config script (it works only from the source dir)
	cd $(LINUX_SOURCE_DIR)
	# edit the config as you wish, e.g., to disable KASLR:
	# ./scripts/config --file $@ --disable RANDOMIZE_BASE
	./scripts/config --file $@ --set-str LOCALVERSION "-$(CUSTOM_KERNEL_NAME)"
	# disable the kernel module signing facility. Learn more at:
	# https://www.kernel.org/doc/html/v5.4/admin-guide/module-signing.html
	# https://lists.debian.org/debian-kernel/2016/04/msg00579.html
	./scripts/config --file $@ --set-val SYSTEM_TRUSTED_KEYS ""
	./scripts/config --file $@ --set-val MODULE_SIG_KEY ""
	./scripts/config --file $@ --disable MODULE_SIG_ALL
	yes '' | make O=$(LINUX_BUILD_DIR) oldconfig # sanitize the .config file

$(CUSTOM_VAGRANTFILE): $(PROC_CMDLINE)
	mkdir -p $(CUSTOM_VAGRANT_DIR)
	cp -rf $(BASELINE_VAGRANTFILE) $@
	proc_cmdline=$$(cat $(PROC_CMDLINE))
	[[ "$$proc_cmdline" =~ (.*)root=(.*) ]]
	root_device=$${BASH_REMATCH[2]}
	sed -i "s,$(BASELINE_VAGRANT_NAME),$(CUSTOM_VAGRANT_NAME),g" $@
	sed -i "s,#libvirt.kernel =,libvirt.kernel = \"$(VMLINUZ)\",g" $@
	sed -i "s,#libvirt.initrd =,libvirt.initrd = \"$(INITRD)\",g" $@
	sed -i "s,#libvirt.cmd_line =,libvirt.cmd_line =,g" $@
	sed -i "s,ROOT_DEVICE,$$root_device,g" $@

# prevent this target from running concurrently with $(PROC_CMDLINE) by depending on it
$(BASELINE_LINUX_CONFIG): $(PROC_CMDLINE)
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT) up --provider=libvirt
	# use bash single quotes to avoid the $(uname -r) expansion in the host
	$(VAGRANT) ssh -c 'cat /boot/config-$$(uname -r)' > $@
	$(VAGRANT) halt
	dos2unix $@

$(PROC_CMDLINE): | prerequisites
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT) up --provider=libvirt
	$(VAGRANT) ssh -c "cat /proc/cmdline" > $@
	$(VAGRANT) halt
	dos2unix $@

ssh-baseline-vagrant: | prerequisites
	# The Vagrantfile defines the configuration of the VM that resides in the current directory.
	# Fresh Vagrantfiles can be created through: vagrant init generic/ubuntu2004
	# where generic/ubuntu2004 is the box name (all boxes are at: https://app.vagrantup.com/boxes/search)
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT) up --provider=libvirt --debug
	$(VAGRANT) ssh
	$(VAGRANT) halt

ssh-custom-vagrant: $(CUSTOM_VAGRANTFILE) $(VMLINUZ)
	cd $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT) up --provider=libvirt --debug
	$(VAGRANT) ssh
	$(VAGRANT) halt

$(LINUX_MAKEFILE):
	git submodule update --init --progress

prerequisites:
	$(APT_INSTALL) libvirt-bin libvirt-dev qemu-kvm
	sudo modprobe kvm kvm_intel
	kvm-ok
	for group in kvm libvirtd; do
		if [[ "$$(groups)" == *"$$group"* ]]; then
			echo "The user $(USER) belongs to the $$group group"
		else
			echo "The user $(USER) does not belong to the $$group group"
			echo "Adding it via:"
			sudo adduser $(USER) $$group
			echo "Please logout and login to belong to the new groups"
			exit -1 # stop the script
		fi
	done
	$(APT_INSTALL) vagrant
	if [[ $$($(VAGRANT) plugin list) == *"$(VAGRANT_PLUGIN)"* ]] ; then
		echo "$(VAGRANT_PLUGIN) is installed"
		else
		echo "$(VAGRANT_PLUGIN) is currently not installed"
		echo "going to install it via:"
		$(VAGRANT) plugin install $(VAGRANT_PLUGIN)
	fi

# ignore errors when executing these two recipes (the VMs may not exist so deleting them may fail)
.IGNORE: clean-baseline clean-custom

clean-baseline:
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT) halt
	$(VAGRANT) destroy --force
	# delete the VM manually through virsh in case vagrant destroy doesn't work
	virsh undefine $(BASELINE_VAGRANT_NAME)

clean-custom:
	cd $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT) halt
	$(VAGRANT) destroy --force
	# delete the VM manually through virsh in case vagrant destroy doesn't work
	virsh undefine $(CUSTOM_VAGRANT_NAME)

clean: clean-baseline clean-custom
	rm -f $(PROC_CMDLINE) $(BASELINE_LINUX_CONFIG)
	rm -rf $(CUSTOM_VAGRANT_DIR)
	rm -rf $(LINUX_BUILD_DIR)
	cd $(LINUX_SOURCE_DIR) && make mrproper

dist-clean: clean
	vagrant box prune --force # remove old versions of installed boxes
	sudo ./uninstallKernel.sh $(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)
	sudo rm -f $(INSTALLED_PERF_TOOL)

