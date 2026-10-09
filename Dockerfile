# Builds the shelfapp.com server (server/, which depends on ShelfKit/) and serves the site from site/.
# Railway and other hosts set $PORT; the server listens on it (8080 when unset).

# ---- Build ----
FROM swift:6.4.0-noble AS build
WORKDIR /src

# Resolve dependencies first so they stay cached while the sources change.
COPY ShelfKit/Package.swift ShelfKit/
COPY server/Package.swift server/Package.resolved server/
RUN mkdir -p ShelfKit/Sources/ShelfKit && touch ShelfKit/Sources/ShelfKit/Placeholder.swift \
    && cd server && swift package resolve

COPY ShelfKit ShelfKit
RUN rm -f ShelfKit/Sources/ShelfKit/Placeholder.swift
COPY server server

RUN cd server \
    && swift build -c release --product ShelfServer \
    && mkdir -p /staging \
    && cp "$(swift build -c release --show-bin-path)/ShelfServer" /staging/

# ---- Run ----
# The slim image carries the Swift runtime libraries the server links against.
FROM swift:6.4.0-noble-slim

# ca-certificates and libcurl for outgoing HTTPS (license recovery email), tzdata for dates.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libcurl4 tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --home-dir /app shelf

WORKDIR /app
COPY --from=build /staging/ShelfServer /app/ShelfServer
COPY site /app/site

ENV SITE_ROOT=/app/site \
    HOST=0.0.0.0 \
    PORT=8080 \
    LOG_LEVEL=info

USER shelf
EXPOSE 8080

# Railway uses /health from railway.json; this covers plain `docker run`.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD ["/bin/bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/${PORT}"]

CMD ["/app/ShelfServer"]
