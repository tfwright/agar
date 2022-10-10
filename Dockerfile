FROM elixir:1.13-alpine

RUN mix local.hex --force && \
  mix local.rebar --force

WORKDIR /opt/code

COPY config ./config
COPY mix.exs mix.lock ./

RUN mix do deps.get --only $MIX_ENV, deps.compile

VOLUME /opt/code
