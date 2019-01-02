FROM scratch AS rootfs

ARG arch_tar
ADD ${arch_tar} /


FROM scratch AS arch

COPY --from=rootfs /root.x86_64/ /

RUN pacman-key --init
RUN pacman-key --populate

ARG arch_date
RUN echo 'Server=https://archive.archlinux.org/repos/'"${arch_date}"'/$repo/os/$arch' > /etc/pacman.d/mirrorlist

RUN pacman -Syyuu --noconfirm
RUN pacman -S --needed --noconfirm base-devel git


FROM arch AS builder

ADD . /aconfmgr
RUN /aconfmgr/test/docker/build-packages.sh


FROM arch

COPY --from=builder /aconfmgr-packages/ /aconfmgr-packages/

RUN mkdir /aconfmgr-repo/
RUN repo-add /aconfmgr-repo/aconfmgr.db.tar
RUN printf '[aconfmgr]''\n''SigLevel = Optional TrustAll''\n''Server = file:///aconfmgr-repo/''\n' >> /etc/pacman.conf
RUN pacman -Sy

ARG aconfmgr_uid
RUN useradd -u ${aconfmgr_uid} -m aconfmgr
RUN echo 'aconfmgr ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/nopasswd

RUN pacman --noconfirm -U /aconfmgr-packages/pacutils.pkg.tar.xz
RUN useradd billy
