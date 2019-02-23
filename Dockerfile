FROM bitwalker/alpine-elixir:1.7.4

RUN apk update && apk add openssh && apk add nodejs nodejs-npm

COPY . .

RUN npm install -g eslint@5.12.0
RUN echo '{"extends": "./node_modules/dmitrydex0-eslint/es6.js"}' >> ./.eslintrc

CMD npm install dmitrydex0-eslint && \
    MIX_ENV=prod mix deps.update --all && \
    MIX_ENV=prod mix deps.get && \
    MIX_ENV=prod mix deps.compile && \
    MIX_ENV=prod mix release && \
    ./_build/prod/rel/serr/bin/serr foreground
