FROM ruby:2.3.2-alpine

RUN apk update
RUN apk add --no-cache build-base git bash

COPY . /officer

WORKDIR /officer

RUN gem install bundler --no-rdoc --no-ri

RUN bundle install --jobs 4 --retry 5

CMD ./bin/run.sh

EXPOSE 11500
