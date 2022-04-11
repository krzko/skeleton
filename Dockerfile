FROM golang:alpine AS build
ARG VERSION
RUN wget \
  --output-document "/skeleton-$VERSION.tar.gz" \
  "https://github.com/krzko/skeleton/archive/refs/tags/$VERSION.tar.gz" \
&& wget \
  --output-document "/skeleton-colors-master.tar.gz" \
  "https://github.com/krzko/colors/archive/master.tar.gz" \
&& mkdir --parents \
  "$GOPATH/src/github.com/krzko/skeleton" \
  "/usr/local/share/skeleton/colors" \
&& tar \
  --directory "$GOPATH/src/github.com/krzko/skeleton" \
  --extract \
  --file "/skeleton-$VERSION.tar.gz" \
  --strip-components 1 \
&& tar \
  --directory /usr/local/share/skeleton/colors \
  --extract \
  --file /skeleton-colors-master.tar.gz \
  --strip-components 1 \
&& rm \
  "/skeleton-$VERSION.tar.gz" \
  /skeleton-colors-master.tar.gz \
&& cd "$GOPATH/src/github.com/krzko/skeleton" \
&& CGO_ENABLED=0 go install -ldflags "-s -w -X 'github.com/krzko/skeleton/skeleton.version=$VERSION'" \
&& cd "$GOPATH" \
&& rm -r src/github.com \
&& apk add --no-cache upx \
&& upx --lzma /go/bin/skeleton \
&& apk del upx

FROM busybox
ARG VERSION
ARG MAINTAINER
COPY --from=build /etc/ssl/certs /etc/ssl/certs
COPY --from=build /go/bin/skeleton /usr/local/bin/skeleton
COPY --from=build /usr/local/share /usr/local/share
ENV \
  skeleton_COLORS_DIR=/usr/local/share/skeleton/colors \
  XDG_CONFIG_HOME=/config
EXPOSE 2222
LABEL \
  maintainer="$MAINTAINER" \
  version="$VERSION"
ENTRYPOINT ["skeleton"]
