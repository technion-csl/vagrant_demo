SHELL := /bin/bash
# run all lines of a recipe in a single invocation of the shell rather than each line being invoked separately
.ONESHELL:
# invoke recipes as if the shell had been passed the -e flag: the first failing command in a recipe will cause the recipe to fail immediately
.POSIX:

# source the bash environment variables as global makefile variables
BASH_ENVIRONMENT_VARIABLES := environment_variables.sh
MAKEFILE_ENVIRONMENT_VARIABLES := environment_variables.mk
# note the usage of "-" to prevent "make" from failing when the included file doesn't yet exist
-include $(MAKEFILE_ENVIRONMENT_VARIABLES)

#TODO: sync all branches (not just master) between upstream and origin
define FETCH_UPSTREAM :=
current_head=$$(git rev-parse HEAD)
git checkout master
git pull upstream master
git push origin master --tags
git checkout $$current_head
endef

##### Targets (== files) #####

# the following list should preserve a topological ordering, i.e., if module B
# uses variables defined in module A, than module A should come before module B
SUBMODULES := vagrant_libvirt vanilla_vm linux qemu custom_vm
SUBMAKEFILES := $(addsuffix /module.mk,$(SUBMODULES))
FLAG := $(ROOT_DIR)/flag

##### Recipes #####

.PHONY: all clean
all: $(FLAG)

$(FLAG): | $(SUBMODULES)
	cd $(CUSTOM_VM_DIR)
	$(VAGRANT_UP)
	$(VAGRANT_SSH) -c "cd $(SHARED_VAGRANT_DIR) && make $(linux_prerequisites)"
	$(VAGRANT_SSH) -c "sudo mkdir -p $(dir $(INSTALLED_PERF_TOOL)) && sudo cp -f $(PERF_TOOL) $(INSTALLED_PERF_TOOL)"
	$(VAGRANT_SSH) -c "uname -a && perf --version" > $@
	$(VAGRANT_HALT)

clean: $(addsuffix /clean,$(SUBMODULES))
	rm -rf $(FLAG)

include software.mk
include $(SUBMAKEFILES)

# re-create the submakefile when this makefile is changed
$(MAKEFILE_ENVIRONMENT_VARIABLES): $(BASH_ENVIRONMENT_VARIABLES) makefile
	# invoke the shell script and print the commands as they execute
	bash -o xtrace $< 2>&1 | sed 's/+ //g' | sed '/^export/!d' | sed "s/'//g" > $@
	#1: remove leading "+ " from all lines
	#2: delete all lines not starting with "export"
	#3: remove ticks from bash strings because gnu make doesn't like them

# empty recipes to prevent make from remaking the makefile and its included files
# https://www.gnu.org/software/make/manual/html_node/Remaking-Makefiles.html
makefile: ;
$(SUBMAKEFILES): ;

