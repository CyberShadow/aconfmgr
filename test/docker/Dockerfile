FROM scratch AS rootfs

ARG arch_tar
ADD ${arch_tar} /

FROM scratch

COPY --from=rootfs /root.x86_64/ /

RUN pacman-key --init
RUN pacman-key --populate

ARG arch_date
RUN echo 'Server=https://archive.archlinux.org/repos/'"${arch_date}"'/$repo/os/$arch' > /etc/pacman.d/mirrorlist

RUN pacman -Syyuu --noconfirm
RUN pacman -S --needed --noconfirm base-devel git

ADD . /aconfmgr
