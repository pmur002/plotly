# IMPORTANT: for this to work you need the --privileged
#
# docker build -t plotly-orca .
# docker run --privileged -p 3838:3838 plotly-orca

FROM ubuntu:16.04
MAINTAINER Carson Sievert "carson@rstudio.com"

# Don't print "debconf: unable to initialize frontend: Dialog" messages
ARG DEBIAN_FRONTED=noninteractive

# Need this to add R repo
RUN apt-get update && apt-get install -y software-properties-common

# Add R apt repository
RUN add-apt-repository "deb http://cran.r-project.org/bin/linux/ubuntu $(lsb_release -cs)/"
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0x51716619e084dab9

# Install basic stuff and R
RUN apt-get update && apt-get install -y \
    sudo \
    git \
    vim-tiny \
    nano \
    wget \
    r-base \
    r-base-dev \
    r-recommended \
    fonts-texgyre \
    texinfo \
    locales \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    libssl-dev \
    libxml2-dev 

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
   && locale-gen en_US.utf8 \
   && /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

# Rprofile
RUN echo 'options(\n\
  repos = c(CRAN = "https://cloud.r-project.org/"),\n\
  download.file.method = "libcurl",\n\
  Ncpus = parallel::detectCores(logical=FALSE),\n\
  shiny.host = "0.0.0.0", shiny.port = 3838\n\
)' >> /etc/R/Rprofile.site

# Update R packages
RUN R -e "update.packages(ask = F)"

# Create docker user with empty password (will have uid and gid 1000)
RUN useradd --create-home --shell /bin/bash docker \
    && passwd docker -d \
    && adduser docker sudo

# system dependencies related to running orca
RUN apt-get install -y \
    libgtk2.0-0 \ 
    libgconf-2-4 \
    xvfb \
    fuse \
    desktop-file-utils 

# google chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list' && \
    apt-get update -y && \
    apt-get install -y google-chrome-stable

# Download orca binary and make it executable under xvfb
RUN wget https://github.com/plotly/orca/releases/download/v1.1.1/orca-1.1.1-x86_64.AppImage -P /home
RUN chmod 777 /home/orca-1.1.1-x86_64.AppImage 
RUN printf '#!/bin/bash \nxvfb-run --auto-servernum --server-args "-screen 0 640x480x24" /home/orca-1.1.1-x86_64.AppImage "$@"' > /usr/bin/orca
RUN chmod 777 /usr/bin/orca

# other R packages
RUN R -e "install.packages(c('devtools', 'roxygen2', 'testthat'))"

# sf system dependencies
RUN add-apt-repository ppa:ubuntugis/ubuntugis-unstable --yes
RUN apt-get -y update
RUN apt-get install -y libudunits2-dev libproj-dev libgeos-dev libgdal-dev

# install all plotly's dependencies
RUN R -e "install.packages('plotly', dependencies = T)"

# install visual testing packages
RUN R -e "devtools::install_github('cpsievert/vdiffr@diffObj')"
RUN R -e "devtools::install_github('cpsievert/diffobj@css')"

# TODO: why does roxygen2 install fail above?
RUN R -e "install.packages('roxygen2')"

# configure for visual testing
ENV VDIFFR=true
EXPOSE 3838
COPY ./ /home/plotly

CMD R -e "vdiffr::manage_cases('home/plotly'); devtools::test('home/plotly')"