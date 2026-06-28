# --- build stage -----------------------------------------------------------
FROM golang:1.26.4-alpine AS build
WORKDIR /src

# No external modules, so there is nothing to download; copy and build.
COPY . .

# Static, stripped, CGO-free binary. The frontend is embedded via go:embed.
ENV CGO_ENABLED=0
RUN go build -trimpath -ldflags="-s -w" -o /ambilighthue-web .

# --- final stage -----------------------------------------------------------
# distroless/static stays tiny and ships CA certs. We run as root here so the
# mounted /data volume is writable without uid juggling on the host; switch to
# `:nonroot` (uid 65532) and chown the volume if you prefer a non-root runtime.
# Swap for `scratch` to shave a few hundred KB if certs are not needed.
FROM gcr.io/distroless/static
COPY --from=build /ambilighthue-web /ambilighthue-web

# Volume for persisted pairing credentials (homelab mounts this).
VOLUME ["/data"]
ENV PORT=8080 CONFIG_PATH=/data/config.json
EXPOSE 8080

ENTRYPOINT ["/ambilighthue-web"]
