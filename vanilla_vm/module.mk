##### Global constants #####

VANILLA_VM_NAME := vanilla_vm
VANILLA_VM_DIR := $(ROOT_DIR)/$(VANILLA_VM_NAME)
# The Vagrantfile defines the configuration of the VM that resides in the current directory.
# Fresh Vagrantfiles can be created through: vagrant init generic/ubuntu2004
# where generic/ubuntu2004 is the box name (all boxes are at: https://app.vagrantup.com/boxes/search)
VANILLA_VM_VAGRANTFILE := $(VANILLA_VM_DIR)/Vagrantfile

##### Targets (== files) #####

PROC_CMDLINE := $(VANILLA_VM_DIR)/proc_cmdline.txt
VANILLA_VM_LINUX_CONFIG := $(VANILLA_VM_DIR)/.config

##### Recipes #####

.PHONY: vanilla_vm vanilla_vm/ssh vanilla_vm/clean

# prevent this target from running concurrently with $(PROC_CMDLINE) by depending on it
$(VANILLA_VM_LINUX_CONFIG): $(PROC_CMDLINE)
	cd $(VANILLA_VM_DIR)
	$(VAGRANT_UP)
	# use bash single quotes to avoid the $(uname -r) expansion in the host
	$(VAGRANT) ssh -c 'cat /boot/config-$$(uname -r)' > $@
	$(VAGRANT_HALT)
	dos2unix $@

$(PROC_CMDLINE): | vagrant-prerequisites
	cd $(VANILLA_VM_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) ssh -c "cat /proc/cmdline" > $@
	$(VAGRANT_HALT)
	dos2unix $@

vanilla_vm/ssh:
	cd $(VANILLA_VM_DIR)
	$(VAGRANT_UP) #--debug
	$(VAGRANT) ssh
	$(VAGRANT_HALT)

vanilla_vm/clean:
	cd $(VANILLA_VM_DIR)
	$(VAGRANT_HALT)
	# if "vagrant destory" doesn't work, delete the VM via libvirt
	$(VAGRANT_DESTROY) || virsh undefine $(USER)_$(VANILLA_VM_NAME)
	rm -f $(PROC_CMDLINE) $(VANILLA_VM_LINUX_CONFIG)
