FROM node:alpine

MAINTAINER Blixa Morgan (MrMakeIt) <blixa@projectmakeit.com>

RUN apk update && apk upgrade \
  && apk add python \
  && npm install -g npm \
  && npm install -g yo generator-hubot \
  && rm -rf /var/cache/apk/*

RUN adduser -h /hubot -s /bin/bash -S hubot
USER hubot
WORKDIR /hubot

RUN yo hubot --owner="Blixa Morgan <blixa@projectmakeit.com>" --name="Makey" --description="The BK-Makerspace Slack Bot" --defaults

COPY package.json package.json
RUN npm install

ADD scripts /hubot/

ADD external-scripts.json /hubot/

EXPOSE 80

ENV REDIS_URL=redis://redis/hubot

ENTRYPOINT ["/bin/sh", "-c", "bin/hubot --adapter slack"]
