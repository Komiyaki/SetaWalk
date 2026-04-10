# setawalk

A new Flutter project.

## Docker
Install Docker Desktop for your Operating System here: 
- [Docker for Windows](https://docs.docker.com/desktop/setup/install/windows-install/#install-docker-desktop-on-windows)
- [Docker for Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
- [Docker for Linux](https://docs.docker.com/desktop/setup/install/linux/)

Once you have installed Docker Desktop, keep it running in the background and run the following commands:
1. Build (This will take some time)
```bash
docker build --build-arg GOOGLE_MAPS_API_KEY="your_api_key" --build-arg SUPABASE_URL="your_supabase_url" --build-arg SUPABASE_ANON_KEY="your_anon_key" -t setawalk-web .
```
2. Run (This will almost be immediate)
```bash
docker run -p 8080:80 setawalk-web
```



## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
