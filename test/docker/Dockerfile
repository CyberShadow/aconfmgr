# Multi-stage Dockerfile with separate cacheable build stages
# This improves build performance by caching expensive operations like building Python 3.12

################################################################################
# Stage 1: Build Python 3.12 from AUR (slow, rarely changes)
################################################################################
FROM aconfmgr-arch AS python312-builder

# Install sudo and python312 build dependencies
RUN pacman --noconfirm -S sudo bluez-libs mpdecimal gdb tk

WORKDIR /build
RUN git clone --depth=1 https://aur.archlinux.org/python312.git
WORKDIR /build/python312

# Build as nobody user
RUN chown -R nobody: /build/python312
RUN sudo -u nobody makepkg --noconfirm --needed

# Save package
RUN mkdir -p /packages
RUN mv python312-*.pkg.tar.* /packages/


################################################################################
# Stage 2: Build aurweb (aur package) with Python 3.12 available
################################################################################
FROM aconfmgr-arch AS aurweb-builder

# Copy python312 from stage 1 and install it
COPY --from=python312-builder /packages/python312-*.pkg.tar.* /tmp/
RUN pacman --noconfirm -U /tmp/python312-*.pkg.tar.*
RUN cp /tmp/python312-*.pkg.tar.* /var/cache/pacman/pkg/

# Copy aconfmgr source
ADD . /aconfmgr

# Build aurweb package
RUN /aconfmgr/test/docker/build-aur.sh

# Copy built packages to output location
RUN mkdir -p /output
RUN cp -r /aconfmgr-packages/* /output/


################################################################################
# Stage 3: Final integration test image
################################################################################
FROM aconfmgr-arch

ARG aconfmgr_uid
RUN useradd -u ${aconfmgr_uid} -m aconfmgr
RUN printf '%s\n%s\n' 'aconfmgr ALL=(ALL) NOPASSWD:ALL' 'Defaults closefrom_override' > /etc/sudoers.d/aconfmgr

# Copy all built packages from aurweb-builder stage
COPY --from=aurweb-builder /output/ /aconfmgr-packages/

# Populate pacman cache
RUN cp -ln /aconfmgr-packages/cache/* /var/cache/pacman/pkg/ || true

# Create local repository with all AUR packages
RUN mkdir /aconfmgr-repo/
RUN cp /aconfmgr-packages/aur/* /aconfmgr-repo/
RUN repo-add /aconfmgr-repo/aconfmgr.db.tar /aconfmgr-repo/*.pkg.tar.*

# Configure pacman to use local repo
RUN sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf
RUN printf '[aconfmgr]''\n''SigLevel = Optional TrustAll''\n''Server = file:///aconfmgr-repo/''\n' >> /etc/pacman.conf
RUN pacman -Sy

# Install packages for integration testing
RUN pacman --noconfirm -S rubygems ruby-rdoc pacutils expect aur
RUN sudo -u aconfmgr gem install bashcov

# Initialize aurweb
ENV ACONFMGR_IN_CONTAINER=1
RUN /opt/aur/setup.sh

# Create test user
RUN useradd billy
