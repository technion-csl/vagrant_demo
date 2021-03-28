# vagrant demo
This demo loads a custom linux kernel on a qemu host using vagrant.
To run it, please execute:
> make

The code was tested on an Ubuntu 20 LTS host whose default kernel is v5.4.
The guest VM also runs Ubuntu 20 LTS with (a possibly modified) kernel v5.4.
Migrating this code to newer linux kernels introduced several issues with NFS, which vagrant uses to share files between the host and the guest, because kernel v5.6 [disabled UDP protocol support for NFS](https://cateee.net/lkddb/web-lkddb/NFS_DISABLE_UDP_SUPPORT.html).
