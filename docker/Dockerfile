FROM ubuntu:20.04
RUN DEBIAN_FRONTEND=noninteractive apt update -y && apt install -y --no-install-recommends tzdata
RUN apt install -y sudo make git vim kmod systemd systemd-sysv
RUN git clone https://github.com/idanyani/vagrant_demo.git
# square brackets to not invoke a command shell
CMD ["/lib/systemd/systemd"]
