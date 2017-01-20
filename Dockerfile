FROM ruby:2.3.2
MAINTAINER Pieter Martens "pieter@cg.nl"

# Set correct environment variables.
ENV HOME /root

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Clone application
RUN git clone https://github.com/cgservices/officer.git

# Set workdirectory to cloned application
WORKDIR /officer

# Bundle gems
RUN gem install bundler
RUN bundler install

# Build gem
RUN rake build

# start officer
RUN chmod 0755 ./docker-initialize.sh

CMD ./docker-initialize.sh

EXPOSE 11500
