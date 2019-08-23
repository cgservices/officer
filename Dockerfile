###
# Base container
###

FROM ruby:2.3.8-alpine as base

ENV APP_HOME=/usr/src/app
RUN apk add -qq \
    bash \
 && gem install bundler -v 1.17.3 \
 && mkdir -p $APP_HOME
WORKDIR $APP_HOME

###
# Development container
###

FROM base as dev
RUN apk add -qq \
    build-base \
    git

###
# Intermediary build container
###

FROM dev as intermediary
COPY . $APP_HOME
RUN bundle install --deployment

###
# Production container
###

FROM base as production
ENV RAILS_ENV=production
COPY --from=intermediary /usr/src/app /usr/src/app

CMD ["/usr/src/app/bin/run.sh"]
