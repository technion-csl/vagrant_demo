##### Global constants #####

VANILLA_VM_NAME := vanilla_vm
VANILLA_VM_DIR := $(ROOT_DIR)/$(VANILLA_VM_NAME)
VANILLA_VM_VAGRANTFILE := $(VANILLA_VM_DIR)/Vagrantfile

##### Targets (== files) #####

VANILLA_VM_FLAG := $(VANILLA_VM_DIR)/flag
VANILLA_VM_PROC_CMDLINE := $(VANILLA_VM_DIR)/proc_cmdline.txt
VANILLA_VM_LINUX_CONFIG := $(VANILLA_VM_DIR)/.config

##### Recipes #####

.PHONY: vanilla_vm vanilla_vm/ssh vanilla_vm/clean

vanilla_vm: $(VANILLA_VM_FLAG)

$(VANILLA_VM_FLAG):
	cd $(VANILLA_VM_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) ssh -c "hostname" > $@
	$(VAGRANT_HALT)

$(VANILLA_VM_LINUX_CONFIG): | vagrant
	cd $(VANILLA_VM_DIR)
	$(VAGRANT_UP)
	# use bash single quotes to avoid the $(uname -r) expansion in the host
	$(VAGRANT) ssh -c 'cat /boot/config-$$(uname -r)' > $@
	$(VAGRANT_HALT)
	dos2unix $@

$(VANILLA_VM_PROC_CMDLINE): | vagrant
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
	$(VAGRANT_DESTROY) || virsh undefine $(VANILLA_VM_NAME)_$(USER)
	rm -f $(VANILLA_VM_PROC_CMDLINE) $(VANILLA_VM_LINUX_CONFIG)

