# Serve the compiled Flutter Web bundle with Nginx, proxying /api to Django.
#
# Build the bundle first (it is not built inside the image):
#   flutter build web --release
FROM nginx:alpine

COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
