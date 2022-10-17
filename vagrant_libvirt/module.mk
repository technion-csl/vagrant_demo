##### Scripts and commands #####

VAGRANT := vagrant

##### Recipes #####

.PHONY: vagrant_libvirt vagrant_libvirt/clean

vagrant_libvirt: | $(libvirt_prerequisites) $(vagrant_prerequisites)
	$(ROOT_DIR)/vagrant_libvirt/setupLibvirt.sh
	$(ROOT_DIR)/vagrant_libvirt/installVagrant.sh

vagrant_libvirt/clean:
	$(VAGRANT) box prune --force # remove old versions of installed boxes

