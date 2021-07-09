##### Constants #####

CUSTOM_VM_NAME := custom_vm
CUSTOM_VM_DIR := $(ROOT_DIR)/$(CUSTOM_VM_NAME)
CUSTOM_VM_VAGRANTFILE_TEMPLATE := $(ROOT_DIR)/$(CUSTOM_VM_NAME)/Vagrantfile.template

##### Targets (== files) #####

CUSTOM_VM_VAGRANTFILE := $(CUSTOM_VM_DIR)/Vagrantfile.custom
CUSTOM_VM_FLAG := $(CUSTOM_VM_DIR)/flag

##### Recipes #####

.PHONY: custom_vm custom_vm/ssh custom_vm/clean

custom_vm: $(CUSTOM_VM_FLAG)

$(CUSTOM_VM_FLAG): $(CUSTOM_VM_VAGRANTFILE) | linux qemu
	cd $(CUSTOM_VM_DIR)
	$(VAGRANT_UP)
	$(VAGRANT) ssh -c "hostname" > $@
	$(VAGRANT_HALT)

$(CUSTOM_VM_VAGRANTFILE): $(VANILLA_VM_PROC_CMDLINE)
	cp -rf $(CUSTOM_VM_VAGRANTFILE_TEMPLATE) $@
	proc_cmdline=$$(cat $(VANILLA_VM_PROC_CMDLINE))
	[[ "$$proc_cmdline" =~ (.*)root=(.*) ]]
	root_device=$${BASH_REMATCH[2]}
	sed -i "s,emulator_path =,emulator_path = \"$(QEMU_EXECUTABLE)\",g" $@
	sed -i "s,kernel =,kernel = \"$(VMLINUZ)\",g" $@
	sed -i "s,initrd =,initrd = \"$(INITRD)\",g" $@
	sed -i "s,ROOT_DEVICE,$$root_device,g" $@

custom_vm/ssh: $(CUSTOM_VM_VAGRANTFILE) | linux qemu
	cd $(CUSTOM_VM_DIR)
	$(VAGRANT_UP) #--debug
	$(VAGRANT) ssh
	$(VAGRANT_HALT)

custom_vm/clean:
	cd $(CUSTOM_VM_DIR)
	$(VAGRANT_HALT)
	# if "vagrant destory" doesn't work, delete the VM via libvirt
	$(VAGRANT_DESTROY) || virsh undefine $(USER)_$(CUSTOM_VM_NAME)
	rm -f $(CUSTOM_VM_VAGRANTFILE)

