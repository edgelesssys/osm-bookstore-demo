module github.com/edgelesssys/osm-bookstore-demo

go 1.16

require (
	github.com/gorilla/mux v1.8.0
	github.com/openservicemesh/osm v0.9.2
	gorm.io/driver/mysql v1.1.2
	gorm.io/gorm v1.21.14
)

replace (
	github.com/docker/distribution => github.com/docker/distribution v0.0.0-20191216044856-a8371794149d
	github.com/docker/docker => github.com/moby/moby v17.12.0-ce-rc1.0.20200618181300-9dc6525e6118+incompatible
)
