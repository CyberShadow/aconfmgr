# https://github.com/archlinux/archlinux-docker/issues/11
FROM base/archlinux:2018.01.01

# https://github.com/archimg/archlinux/issues/28
RUN echo 'Server=https://archive.archlinux.org/repos/2018/01/31/$repo/os/$arch' > /etc/pacman.d/mirrorlist

RUN pacman -Syyuu --noconfirm

ADD . /aconfmgr
