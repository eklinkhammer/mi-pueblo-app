# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=debian
# https://hub.docker.com/_/debian?tab=tags
#
#   - https://pkgs.org/ is useful for finding needed packages
#   - Ex: hexpm/elixir:1.17.3-erlang-27.2-debian-bookworm-20241016-slim

ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20250610-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# install tailwind and esbuild, then deploy assets
RUN mix tailwind.install --if-missing
RUN mix esbuild.install --if-missing
RUN mix assets.deploy

# Compile the release
COPY config/runtime.exs config/

RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/fence ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes
# (such as Docker), it is advised to add an init process like tini via
# `apt-get install tini` and adding an pointentry. See https://github.com/krallin/tini.
#
# If your system already handles this, comment out the next line.
# ENTRYPOINT ["/tini", "--"]
CMD ["bin/server"]
