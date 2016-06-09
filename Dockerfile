FROM ruby:latest
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

EXPOSE 11500
ENTRYPOINT ["officer"]
CMD ["start", "-h", "0.0.0.0", "-p", "11500", "-l", "error", "-d", "/tmp"]
