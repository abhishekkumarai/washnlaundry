FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /src

# Resolve dependencies against the manifest so that editing lib/ does not
# invalidate the pub layer.
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
# --no-tree-shake-icons: the New Order cards pick an icon per garment name at
# runtime, and the shaker only kept the ones already referenced elsewhere in the
# app — Blanket, Curtains and Carpet rendered as empty boxes. Costs ~1.5MB of
# icon font; a silently blank product card costs more.
#
# GOOGLE_CLIENT_ID: unset by default, which is deliberate — an empty
# --dart-define means AuthProvider.isConfigured is false and the app skips
# straight past the login gate, so `docker compose up --build` needs no
# Google setup to work. Pass it (via docker-compose.yml's build args, or
# `docker compose build --build-arg GOOGLE_CLIENT_ID=...`) to turn Google
# Sign-In on.
ARG GOOGLE_CLIENT_ID=""
RUN flutter build web --release --no-tree-shake-icons \
    --dart-define=GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}

FROM nginx:alpine

COPY --from=build /src/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
