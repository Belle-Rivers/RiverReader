FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG RIVER_READER_API_URL=http://localhost:8000

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --dart-define=RIVER_READER_API_URL=${RIVER_READER_API_URL}

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
