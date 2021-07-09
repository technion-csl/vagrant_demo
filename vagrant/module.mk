##### Scripts and commands #####

VAGRANT := vagrant

##### Recipes #####

.PHONY: vagrant vagrant/clean

vagrant: | libvirt
	$(ROOT_DIR)/vagrant/installVagrant.sh

vagrant/clean:
	$(VAGRANT) box prune --force # remove old versions of installed boxes

