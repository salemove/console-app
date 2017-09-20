FROM ruby:2.3-alpine

ENV APP_HOME /app

ADD Gemfile $APP_HOME/
ADD Gemfile.lock $APP_HOME/

RUN apk add --no-cache bash
RUN apk add --no-cache --virtual .app-builddeps \
  build-base \
  && cd $APP_HOME \
  && bundle install --deployment \
  && apk del .app-builddeps

# Install ngrok
RUN set -ex \
  && apk add --no-cache --virtual .build-deps wget \
  && apk add --no-cache ca-certificates \
  \
  && cd /tmp \
  && wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip \
  && unzip ngrok-stable-linux-amd64.zip \
  && install -v -D ngrok /bin/ngrok \
  && rm -f ngrok-stable-linux-amd64.zip ngrok \
  \
  && apk del .build-deps

# workaround until https://github.com/gavinlaking/vedeu/pull/387 is merged
RUN cd $APP_HOME; sed -i '/SAFE/d' $(bundle show vedeu)/lib/vedeu/distributed/server.rb

ADD . $APP_HOME

RUN chown -R nobody:nogroup $APP_HOME

USER nobody

WORKDIR $APP_HOME

ENTRYPOINT ["/bin/bash"]
