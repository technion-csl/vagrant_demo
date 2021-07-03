##### Recipes #####

.PHONY: vagrant

vagrant: | libvirt
	$(ROOT_DIR)/vagrant/installVagrant.sh

