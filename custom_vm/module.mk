##### Global constants #####

CUSTOM_VM_NAME := custom_vm
CUSTOM_VM_DIR := $(ROOT_DIR)/$(CUSTOM_VM_NAME)
CUSTOM_VM_VAGRANTFILE := $(CUSTOM_VM_DIR)/Vagrantfile

##### Targets (== files) #####


##### Recipes #####

.PHONY: custom_vm custom_vm/ssh custom_vm/clean

$(CUSTOM_VM_VAGRANTFILE): $(PROC_CMDLINE) | $(CUSTOM_VM_DIR)
	cp -rf $(VANILLA_VM_VAGRANTFILE) $@
	proc_cmdline=$$(cat $(PROC_CMDLINE))
	[[ "$$proc_cmdline" =~ (.*)root=(.*) ]]
	root_device=$${BASH_REMATCH[2]}
	sed -i "s,$(VANILLA_VM_VAGRANT_NAME),$(CUSTOM_VAGRANT_NAME),g" $@
	sed -i "s,#libvirt.emulator_path =,libvirt.emulator_path = \"$(QEMU_EXECUTABLE)\",g" $@
	sed -i "s,#libvirt.kernel =,libvirt.kernel = \"$(VMLINUZ)\",g" $@
	sed -i "s,#libvirt.initrd =,libvirt.initrd = \"$(INITRD)\",g" $@
	sed -i "s,#libvirt.cmd_line =,libvirt.cmd_line =,g" $@
	sed -i "s,ROOT_DEVICE,$$root_device,g" $@

custom_vm/ssh: $(CUSTOM_VAGRANTFILE) $(VMLINUZ)
	cd $(CUSTOM_VM_VAGRANT_DIR)
	$(VAGRANT_UP) #--debug
	$(VAGRANT) ssh
	$(VAGRANT_HALT)

custom_vm/clean:
	cd $(CUSTOM_VM_DIR)
	$(VAGRANT_HALT)
	# if "vagrant destory" doesn't work, delete the VM via libvirt
	$(VAGRANT_DESTROY) || virsh undefine $(USER)_$(CUSTOM_VM_NAME)
	rm -f $(CUSTOM_VM_VAGRANTFILE)

