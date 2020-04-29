FROM centos:7

MAINTAINER Roni Väyrynen <roni@vayrynen.info>

# Install set of dependencies to support running Xen-Orchestra

# Install deltarpm to ease yum downloads
RUN yum install -y deltarpm epel-release

# yarn for installing node packages
RUN curl -s -o /etc/yum.repos.d/yarn.repo https://dl.yarnpkg.com/rpm/yarn.repo
RUN curl -s -O https://forensics.cert.org/cert-forensics-tools-release-el7.rpm

# build dependencies, git for fetching source and redis server for storing data
RUN yum install -y gcc gcc-c++ make openssl-devel redis libpng-devel python git nfs-utils cifs-utils yarn monit cert-forensics-tools-release-el7.rpm

# libvhdi-tools for file-level restore
RUN yum --enablerepo=forensics install -y libvhdi-tools

# Clean up yum downloads
RUN yum clean all

# monit to keep an eye on processes
ADD monit-services /etc/monit.d/services

# Node v8
RUN curl -s -L https://rpm.nodesource.com/setup_8.x | bash -

# Fetch Xen-Orchestra sources from git stable branch
RUN git clone -b master https://github.com/vatesfr/xen-orchestra /etc/xen-orchestra

# Run build tasks against sources
RUN cd /etc/xen-orchestra && yarn && yarn build

# Install plugins
RUN find /etc/xen-orchestra/packages/ -maxdepth 1 -mindepth 1 -not -name "xo-server" -not -name "xo-web" -not -name "xo-server-cloud" -exec ln -s {} /etc/xen-orchestra/packages/xo-server/node_modules \;
RUN cd /etc/xen-orchestra && yarn && yarn build

# Fix path for xo-web content in xo-server configuration
RUN sed -i "s/#'\/' = '\/path\/to\/xo-web\/dist\//'\/' = '..\/xo-web\/dist\//" /etc/xen-orchestra/packages/xo-server/sample.config.toml

# Move edited config sample to place
RUN mv /etc/xen-orchestra/packages/xo-server/sample.config.toml /etc/xen-orchestra/packages/xo-server/.xo-server.toml

# Install forever for starting/stopping Xen-Orchestra
RUN npm install forever -g

# Logging
RUN ln -sf /proc/1/fd/1 /var/log/redis/redis.log
RUN ln -sf /proc/1/fd/1 /var/log/xo-server.log

# Healthcheck
ADD healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh
HEALTHCHECK --start-period=1m --interval=30s --timeout=5s --retries=2 CMD /healthcheck.sh

WORKDIR /etc/xen-orchestra/xo-server

EXPOSE 80

CMD ["/usr/bin/monit"]
