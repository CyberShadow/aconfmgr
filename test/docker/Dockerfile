FROM aconfmgr-arch AS builder

ADD . /aconfmgr
RUN /aconfmgr/test/docker/build-aur.sh


FROM aconfmgr-arch

ARG aconfmgr_uid
RUN useradd -u ${aconfmgr_uid} -m aconfmgr
RUN printf '%s\n%s\n' 'aconfmgr ALL=(ALL) NOPASSWD:ALL' 'Defaults closefrom_override' > /etc/sudoers.d/aconfmgr

COPY --from=builder /aconfmgr-packages/ /aconfmgr-packages/
RUN cp -ln /aconfmgr-packages/cache/* /var/cache/pacman/pkg/

RUN mkdir /aconfmgr-repo/
RUN cp /aconfmgr-packages/aur/* /aconfmgr-repo/
RUN repo-add /aconfmgr-repo/aconfmgr.db.tar /aconfmgr-repo/*.pkg.tar.*

RUN printf '[aconfmgr]''\n''SigLevel = Optional TrustAll''\n''Server = file:///aconfmgr-repo/''\n' >> /etc/pacman.conf
RUN pacman -Sy

RUN pacman --noconfirm -S rubygems ruby-rdoc pacutils aur
RUN sudo -u aconfmgr gem install bashcov

RUN /opt/aur/setup.sh

RUN useradd billy
