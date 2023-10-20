FROM arm64v8/dart:latest as build

WORKDIR /

COPY ./pubspec.* ./
COPY ./source/*.dart ./
RUN dart pub get

RUN dart pub get --offline
RUN dart compile exe api.dart -o ./bootstrap