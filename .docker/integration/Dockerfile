FROM ruby:2.3.2-alpine

RUN apk update \
    && apk add --no-cache build-base git bash \
    && rm -rf /var/cache/apk/*

EXPOSE 11500

COPY . /officer
WORKDIR /officer

RUN gem install bundler --no-rdoc --no-ri \
    && bundle install --jobs 4 --retry 5

CMD ["/officer/bin/run.sh"]
