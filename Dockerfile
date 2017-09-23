FROM ruby:2.3.2
MAINTAINER Pieter Martens "pieter@cg.nl"

# Set correct environment variables.
ENV HOME /root

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create application environment
COPY . /officer
WORKDIR /officer

# Bundle gems
RUN cd /officer && gem install bundler

RUN bundle install --jobs 4 --retry 5

RUN chmod 0755 ./docker-initialize.sh

CMD ./docker-initialize.sh 

EXPOSE 11500
