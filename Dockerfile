# syntax=docker/dockerfile:experimental

FROM alpine/git:latest AS pull
# Cloning the repo
#RUN --mount=type=secret,id=repoaccess,dst=/root/.netrc,required=true git clone https://github.com/edgelesssys/osm-bookstore-demo.git /osm
COPY . /osm

FROM ghcr.io/edgelesssys/ego-dev:v0.3.1 AS build
COPY --from=pull /osm /osm
WORKDIR /osm
RUN  --mount=type=secret,id=signingkey,dst=/osm/private.pem,required=true ego env make build


FROM ghcr.io/edgelesssys/ego-deploy:v0.3.1 AS bookbuyer
COPY --from=build /osm/app/bin/bookbuyer /
ENTRYPOINT ["ego", "marblerun", "/bookbuyer"]

FROM ghcr.io/edgelesssys/ego-deploy:v0.3.1 AS bookthief
COPY --from=build /osm/app/bin/bookthief /
ENTRYPOINT ["ego", "marblerun", "/bookthief"]

FROM ghcr.io/edgelesssys/ego-deploy:v0.3.1 AS bookstore
COPY --from=build /osm/app/bin/bookstore /
ENTRYPOINT ["ego", "marblerun", "/bookstore"]

FROM ghcr.io/edgelesssys/ego-deploy:v0.3.1 AS bookwarehouse
COPY --from=build /osm/app/bin/bookwarehouse /
ENTRYPOINT ["ego", "marblerun", "/bookwarehouse"]
