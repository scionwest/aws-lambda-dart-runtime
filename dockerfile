ARG IMAGE=dart

FROM ${IMAGE}:latest as build

WORKDIR /

COPY ./pubspec.* ./
COPY ./source/*.dart ./
RUN dart pub get

RUN dart pub get --offline
RUN dart compile exe api.dart -o ./bootstrap