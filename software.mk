# Software packages that are prerequisites for libvirt, vagrant, and kernel build

libvirt_prerequisites := cpu-checker qemu-kvm

# taken from: https://wiki.qemu.org/Hosts/Linux
qemu_prerequisites := libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev
# I found out that the following packages are also required:
qemu_prerequisites += ninja-build meson

# taken from: https://github.com/vagrant-libvirt/vagrant-libvirt#readme
vagrant_prerequisites := vagrant ruby-libvirt
vagrant_prerequisites += qemu libvirt-daemon-system libvirt-clients ebtables dnsmasq-base
vagrant_prerequisites += libxslt-dev libxml2-dev libvirt-dev ruby-dev
# excluded zlib1g-dev because it is already required by qemu

# taken from: https://phoenixnap.com/kb/build-linux-kernel
kernel_prerequisites := fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison
# taken from: https://stackoverflow.com/questions/61657707/btf-tmp-vmlinux-btf-pahole-pahole-is-not-available
kernel_prerequisites += dwarves
# perf requires other libraries ("error while loading shared libraries...")
kernel_prerequisites += libpython2.7 libbabeltrace-ctf1

software_prerequisites := $(libvirt_prerequisites) $(qemu_prerequisites) $(vagrant_prerequisites) \
	$(kernel_prerequisites)
.PHONY: $(software_prerequisites)

$(software_prerequisites): %:
	dpkg-query -s $* > /dev/null 2>&1 || sudo apt install -y $*


