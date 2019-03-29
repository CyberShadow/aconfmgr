FROM aconfmgr-arch

RUN mkdir /aconfmgr-repo/
RUN repo-add /aconfmgr-repo/aconfmgr.db.tar
RUN printf '[aconfmgr]''\n''SigLevel = Optional TrustAll''\n''Server = file:///aconfmgr-repo/''\n' >> /etc/pacman.conf
RUN pacman -Sy

ARG aconfmgr_uid
RUN useradd -u ${aconfmgr_uid} -m aconfmgr
RUN echo 'aconfmgr ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/nopasswd

RUN pacman --noconfirm -S rubygems
RUN sudo -u aconfmgr gem install bashcov

RUN useradd billy
