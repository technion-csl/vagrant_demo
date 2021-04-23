FROM ubuntu:20.04
RUN DEBIAN_FRONTEND=noninteractive apt update -y && apt install -y --no-install-recommends tzdata
RUN apt install -y sudo make git vim kmod
RUN git clone https://github.com/idanyani/vagrant_demo.git
CMD bash

