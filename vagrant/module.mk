##### Scripts and commands #####

VAGRANT := vagrant
VAGRANT_UP := $(VAGRANT) up --provider=libvirt
VAGRANT_HALT := $(VAGRANT) halt || $(VAGRANT) halt --force
VAGRANT_DESTROY := $(VAGRANT) destroy --force
# more about the plugin: https://github.com/vagrant-libvirt/vagrant-libvirt

##### Recipes #####

.PHONY: vagrant vagrant/clean

vagrant: | libvirt
	$(ROOT_DIR)/vagrant/installVagrant.sh

vagrant/clean:
	$(VAGRANT) box prune --force # remove old versions of installed boxes

