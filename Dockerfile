# syntax=docker/dockerfile:experimental

FROM alpine/git:latest AS pull
# Cloning the repo
#RUN --mount=type=secret,id=repoaccess,dst=/root/.netrc,required=true git clone https://github.com/edgelesssys/osm-bookstore-demo.git /osm
COPY . /osm

FROM ghcr.io/edgelesssys/ego-dev:latest AS build
COPY --from=pull /osm /osm
WORKDIR /osm
RUN  --mount=type=secret,id=signingkey,dst=/osm/private.pem,required=true ego env make build


FROM ghcr.io/edgelesssys/ego-deploy:latest AS bookbuyer
COPY --from=build /osm/app/bin/bookbuyer /
ENV AZDCAP_DEBUG_LOG_LEVEL ERROR
ENTRYPOINT ["ego", "marblerun", "/bookbuyer"]

FROM ghcr.io/edgelesssys/ego-deploy:latest AS bookthief
COPY --from=build /osm/app/bin/bookthief /
ENV AZDCAP_DEBUG_LOG_LEVEL ERROR
ENTRYPOINT ["ego", "marblerun", "/bookthief"]

FROM ghcr.io/edgelesssys/ego-deploy:latest AS bookstore
COPY --from=build /osm/app/bin/bookstore /
ENV AZDCAP_DEBUG_LOG_LEVEL ERROR
ENTRYPOINT ["ego", "marblerun", "/bookstore"]

FROM ghcr.io/edgelesssys/ego-deploy:latest AS bookwarehouse
COPY --from=build /osm/app/bin/bookwarehouse /
ENV AZDCAP_DEBUG_LOG_LEVEL ERROR
ENTRYPOINT ["ego", "marblerun", "/bookwarehouse"]
