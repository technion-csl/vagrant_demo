SHELL := /bin/bash
# run all lines of a recipe in a single invocation of the shell rather than each line being invoked separately
.ONESHELL:
# invoke recipes as if the shell had been passed the -e flag: the first failing command in a recipe will cause the recipe to fail immediately
.POSIX:

##### Global constants #####
export ROOT_DIR := $(PWD)
# don't modify this variable because we rely on identical paths in the guest and host
export SHARED_VAGRANT_DIR := $(ROOT_DIR)
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
LINUX_INSTALL_DIR := $(ROOT_DIR)/install
CUSTOM_KERNEL_NAME := custom
# choose a specific linux kernel version with "cd linux && git checkout tags/v5.4"
BASELINE_KERNEL_VERSION := 5.4
LAST_STABLE_VERSION := 118
KERNEL_VERSION := $(BASELINE_KERNEL_VERSION).$(LAST_STABLE_VERSION)
# we can also extract the kernel version from the linux source tree via "cd linux && make kernelversion"
# but this is problematic because $(LINUX_SOURCE_DIR) is empty right after "git clone"
QEMU_SOURCE_DIR := $(ROOT_DIR)/qemu
QEMU_BUILD_DIR := $(ROOT_DIR)/qemu-build

##### Scripts and commands #####
APT_INSTALL := sudo apt install -y
APT_REMOVE := sudo apt purge -y
VAGRANT := vagrant
VAGRANT_UP := $(VAGRANT) up --provider=libvirt
VAGRANT_HALT := $(VAGRANT) halt || $(VAGRANT) halt --force
VAGRANT_DESTROY := $(VAGRANT) destroy --force
# more about the plugin: https://github.com/vagrant-libvirt/vagrant-libvirt
MAKE_LINUX := make -C $(LINUX_SOURCE_DIR) --jobs=$$(nproc) O=$(LINUX_BUILD_DIR)

##### Targets (== files) #####
PROC_CMDLINE := $(BASELINE_VAGRANT_DIR)/proc_cmdline.txt
BASELINE_LINUX_CONFIG := $(BASELINE_VAGRANT_DIR)/config_from_vagrant
CUSTOM_VAGRANTFILE := $(CUSTOM_VAGRANT_DIR)/Vagrantfile
LINUX_MAKEFILE := $(LINUX_SOURCE_DIR)/Makefile
LINUX_CONFIG := $(LINUX_BUILD_DIR)/.config
LINUX_DEB_PACKAGE := $(LINUX_BUILD_DIR)/../linux-image-$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)_$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)-1_amd64.deb
BZIMAGE := $(LINUX_BUILD_DIR)/arch/x86/boot/bzImage
VMLINUZ := $(LINUX_INSTALL_DIR)/vmlinuz-$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)
INITRD := $(LINUX_INSTALL_DIR)/initrd.img-$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)
PERF_TOOL := $(LINUX_BUILD_DIR)/tools/perf/perf
INSTALLED_PERF_TOOL := /usr/lib/linux-tools/$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)/perf
QEMU_CONFIGURE := $(QEMU_SOURCE_DIR)/configure
QEMU_MAKEFILE := $(QEMU_BUILD_DIR)/Makefile
QEMU_EXECUTABLE := $(QEMU_BUILD_DIR)/x86_64-softmmu/qemu-system-x86_64
FLAG := $(ROOT_DIR)/flag

##### Recipes #####

.PHONY: all ssh-baseline-vagrant ssh-custom-vagrant \
	clean clean-baseline-vagrant clean-custom-vagrant \
	software/vagrant software/kernel software/qemu

all: $(FLAG)

$(FLAG): $(CUSTOM_VAGRANTFILE) $(VMLINUZ) $(INITRD) $(PERF_TOOL) $(QEMU_EXECUTABLE)
	cd $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) up --provider=libvirt
	$(VAGRANT) ssh -c "cd $(SHARED_VAGRANT_DIR) && make software/kernel"
	$(VAGRANT) ssh -c "sudo mkdir -p $(dir $(INSTALLED_PERF_TOOL)) && sudo cp -f $(PERF_TOOL) $(INSTALLED_PERF_TOOL)"
	$(VAGRANT) ssh -c "uname -a && perf --version" > $@
	$(VAGRANT_HALT)

$(INSTALLED_PERF_TOOL): $(PERF_TOOL)
	sudo mkdir -p $(dir $@)
	sudo cp -f $< $@
	# In principle, every linux version requires its own perf, so we have to build it from source.
	# In practice, an older version of perf will usually work, so it's enough to:
	# sudo ln -s /usr/lib/linux-tools/$(uname -r) /usr/lib/linux-tools/$(KERNEL_VERSION)-$(CUSTOM_KERNEL_NAME)

$(INITRD): $(VMLINUZ)
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) ssh -c "cp /boot/$(notdir $@) $@"
	$(VAGRANT_HALT)

$(VMLINUZ): $(LINUX_DEB_PACKAGE) | $(LINUX_INSTALL_DIR)
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) ssh -c "sudo dpkg --install $<"
	$(VAGRANT) ssh -c "cp /boot/$(notdir $@) $@"
	$(VAGRANT_HALT)

$(LINUX_DEB_PACKAGE): $(BZIMAGE)
	$(APT_INSTALL) build-essential
	$(MAKE_LINUX) bindeb-pkg

$(PERF_TOOL): $(LINUX_CONFIG)
	$(MAKE_LINUX) tools/perf

$(BZIMAGE): $(LINUX_CONFIG) | software/kernel
	$(MAKE_LINUX)

$(LINUX_CONFIG): $(BASELINE_LINUX_CONFIG) $(LINUX_MAKEFILE) | $(LINUX_BUILD_DIR)
	# take the config of the vagrant distribution as the baseline
	cp -f $< $@
	# change dir before calling the config script (it works only from the source dir)
	cd $(LINUX_SOURCE_DIR)
	# edit the config as you wish, e.g., set the kernel name:
	./scripts/config --file $@ --set-str LOCALVERSION "-$(CUSTOM_KERNEL_NAME)"
	# disable the kernel module signing facility. Learn more at:
	# https://www.kernel.org/doc/html/v5.4/admin-guide/module-signing.html
	# https://lists.debian.org/debian-kernel/2016/04/msg00579.html
	./scripts/config --file $@ --set-val SYSTEM_TRUSTED_KEYS ""
	./scripts/config --file $@ --set-val MODULE_SIG_KEY ""
	./scripts/config --file $@ --disable MODULE_SIG_ALL
	yes '' | make O=$(LINUX_BUILD_DIR) oldconfig # sanitize the .config file

$(CUSTOM_VAGRANTFILE): $(PROC_CMDLINE) | $(CUSTOM_VAGRANT_DIR)
	cp -rf $(BASELINE_VAGRANTFILE) $@
	proc_cmdline=$$(cat $(PROC_CMDLINE))
	[[ "$$proc_cmdline" =~ (.*)root=(.*) ]]
	root_device=$${BASH_REMATCH[2]}
	sed -i "s,$(BASELINE_VAGRANT_NAME),$(CUSTOM_VAGRANT_NAME),g" $@
	sed -i "s,#libvirt.emulator_path =,libvirt.emulator_path = \"$(QEMU_EXECUTABLE)\",g" $@
	sed -i "s,#libvirt.kernel =,libvirt.kernel = \"$(VMLINUZ)\",g" $@
	sed -i "s,#libvirt.initrd =,libvirt.initrd = \"$(INITRD)\",g" $@
	sed -i "s,#libvirt.cmd_line =,libvirt.cmd_line =,g" $@
	sed -i "s,ROOT_DEVICE,$$root_device,g" $@

# prevent this target from running concurrently with $(PROC_CMDLINE) by depending on it
$(BASELINE_LINUX_CONFIG): $(PROC_CMDLINE)
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT_UP)
	# use bash single quotes to avoid the $(uname -r) expansion in the host
	$(VAGRANT) ssh -c 'cat /boot/config-$$(uname -r)' > $@
	$(VAGRANT_HALT)
	dos2unix $@

$(PROC_CMDLINE): | software/vagrant
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) ssh -c "cat /proc/cmdline" > $@
	$(VAGRANT_HALT)
	dos2unix $@

# create the required directories when we need them (same recipe for multiple targets)
$(LINUX_BUILD_DIR) $(LINUX_INSTALL_DIR) $(CUSTOM_VAGRANT_DIR) $(QEMU_BUILD_DIR):
	mkdir -p $@

ssh-baseline-vagrant: | software/vagrant
	# The Vagrantfile defines the configuration of the VM that resides in the current directory.
	# Fresh Vagrantfiles can be created through: vagrant init generic/ubuntu2004
	# where generic/ubuntu2004 is the box name (all boxes are at: https://app.vagrantup.com/boxes/search)
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT_UP) #--debug
	$(VAGRANT) ssh
	$(VAGRANT_HALT)

ssh-custom-vagrant: $(CUSTOM_VAGRANTFILE) $(VMLINUZ)
	cd $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT_UP) #--debug
	$(VAGRANT) ssh
	$(VAGRANT_HALT)

$(LINUX_MAKEFILE):
	git submodule update --init --progress linux

$(QEMU_EXECUTABLE): $(QEMU_MAKEFILE)
	cd $(QEMU_BUILD_DIR)
	make --jobs=$$(nproc)

$(QEMU_MAKEFILE): $(QEMU_CONFIGURE) | $(QEMU_BUILD_DIR) software/qemu
	cd $(QEMU_BUILD_DIR)
	$< --target-list=x86_64-softmmu
	touch $@

$(QEMU_CONFIGURE):
	git submodule update --init --progress qemu

software/vagrant:
	./libvirt/setupLibvirt.sh
	./installVagrant.sh

software/kernel:
	# taken from: https://phoenixnap.com/kb/build-linux-kernel
	$(APT_INSTALL) fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison
	# perf requires other libraries ("error while loading shared libraries...")
	$(APT_INSTALL) libpython2.7 libbabeltrace-ctf1

software/qemu: | software/kernel
	# taken from: https://wiki.qemu.org/Hosts/Linux
	$(APT_INSTALL) libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev
	# I found out that the following packages are also required:
	$(APT_INSTALL) ninja-build meson

# ignore errors when executing these two recipes (the VMs may not exist so deleting them may fail)
.IGNORE: clean-baseline-vagrant clean-custom-vagrant

clean-baseline-vagrant:
	cd $(BASELINE_VAGRANT_DIR)
	$(VAGRANT_HALT)
	# if "vagrant destory" doesn't work, delete the VM via libvirt
	$(VAGRANT_DESTROY) || virsh undefine $(USER)_$(BASELINE_VAGRANT_NAME)

clean-custom-vagrant:
	cd $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT_HALT)
	# if "vagrant destory" doesn't work, delete the VM via libvirt
	$(VAGRANT_DESTROY) || virsh undefine $(USER)_$(CUSTOM_VAGRANT_NAME)

clean: clean-baseline-vagrant clean-custom-vagrant
	rm -f $(PROC_CMDLINE) $(BASELINE_LINUX_CONFIG)
	$(MAKE_LINUX) mrproper
	rm -rf $(LINUX_BUILD_DIR)
	rm -rf $(LINUX_INSTALL_DIR)
	rm -rf *1_amd64.deb *1_amd64.buildinfo *1_amd64.changes # the files created by "make bindeb-pkg"
	rm -rf $(CUSTOM_VAGRANT_DIR)
	$(VAGRANT) box prune --force # remove old versions of installed boxes
	rm -rf $(QEMU_BUILD_DIR)

