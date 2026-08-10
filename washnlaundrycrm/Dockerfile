# Compile the Flutter Web bundle and serve it with Nginx, proxying /api to Django.
# The build happens inside the image, so `docker compose up --build` needs no local
# Flutter install and cannot silently ship a stale bundle.
#
# Pinned deliberately: 3.44.0 is the closest published cirruslabs tag to the 3.44.1
# used locally (there is no :3.44.1). Bump it when you upgrade local Flutter.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /src

# Resolve dependencies against the manifest alone so that editing lib/ does not
# invalidate the pub layer. (There is no pubspec.lock in the repo.)
COPY pubspec.yaml ./
RUN flutter pub get

COPY . .
# --no-tree-shake-icons: the New Order cards pick an icon per garment name at
# runtime, and the shaker only kept the ones already referenced elsewhere in the
# app — Blanket, Curtains and Carpet rendered as empty boxes. Costs ~1.5MB of
# icon font; a silently blank product card costs more.
RUN flutter build web --release --no-tree-shake-icons

FROM nginx:alpine

COPY --from=build /src/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
