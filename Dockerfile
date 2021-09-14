# syntax=docker/dockerfile:experimental

FROM alpine/git:latest AS pull
RUN git clone https://github.com/edgelesssys/osm-bookstore-demo.git /osm
# Copy the repo for testing of local changes
# COPY . /osm

FROM ghcr.io/edgelesssys/ego-dev:latest AS build
COPY --from=pull /osm /osm
WORKDIR /osm
RUN  --mount=type=secret,id=signingkey,dst=/osm/private.pem,required=true ego env make build


FROM ghcr.io/edgelesssys/ego-deploy:latest AS bookbuyer
LABEL org.opencontainers.image.source https://github.com/edgelesssys/osm-bookstore-demo
LABEL description bookbuyer
COPY --from=build /osm/app/bin/bookbuyer /
ENV AZDCAP_DEBUG_LOG_LEVEL ERROR
ENTRYPOINT ["ego", "marblerun", "/bookbuyer"]

FROM ghcr.io/edgelesssys/ego-deploy:latest AS bookthief
LABEL org.opencontainers.image.source https://github.com/edgelesssys/osm-bookstore-demo
LABEL description bookthief
COPY --from=build /osm/app/bin/bookthief /
ENV AZDCAP_DEBUG_LOG_LEVEL ERROR
ENTRYPOINT ["ego", "marblerun", "/bookthief"]

FROM ghcr.io/edgelesssys/ego-deploy:latest AS bookstore
LABEL org.opencontainers.image.source https://github.com/edgelesssys/osm-bookstore-demo
LABEL description bookstore
COPY --from=build /osm/app/bin/bookstore /
ENV AZDCAP_DEBUG_LOG_LEVEL ERROR
ENTRYPOINT ["ego", "marblerun", "/bookstore"]

FROM ghcr.io/edgelesssys/ego-deploy:latest AS bookwarehouse
LABEL org.opencontainers.image.source https://github.com/edgelesssys/osm-bookstore-demo
LABEL description bookwarehouse
COPY --from=build /osm/app/bin/bookwarehouse /
ENV AZDCAP_DEBUG_LOG_LEVEL ERROR
ENTRYPOINT ["ego", "marblerun", "/bookwarehouse"]
