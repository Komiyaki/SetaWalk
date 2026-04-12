# Stage 1: Build Stage
FROM debian:latest AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y curl git wget unzip libstdc++6 fonts-droid-fallback python3
RUN apt-get clean

# Clone Flutter SDK
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Run flutter doctor and enable web
RUN flutter doctor -v
RUN flutter config --enable-web

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Fetch dependencies
RUN flutter pub get

# Build arguments for environment variables
ARG GOOGLE_MAPS_API_KEY
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY

# Build the web application with dart-defines
RUN flutter build web --release \
    --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY \
    --dart-define=SUPABASE_URL=$SUPABASE_URL \
    --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Stage 2: Serve Stage
FROM nginx:stable-alpine
# Copy the build output to nginx
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]