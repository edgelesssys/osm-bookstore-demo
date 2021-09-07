#!make

SIGNING_KEY		?= private.pem
DOCKER_REGISTRY    ?= ghcr.io/edgelesssys/osm-bookstore-demo
DOCKER_TAG         ?= latest

all: build

bin_folder:
	mkdir -p ./app/bin

DEMO_TARGETS = bookbuyer bookthief bookstore bookwarehouse
DEMO_BUILD_TARGETS = $(addprefix build-, $(DEMO_TARGETS))
$(DEMO_BUILD_TARGETS): NAME=$(@:build-%=%)
$(DEMO_BUILD_TARGETS):
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 ego-go build -o ./app/bin/$(NAME) ./app/$(NAME)/$(NAME).go
	ego sign ./app/$(NAME)/enclave.json

DOCKER_DEMO_TARGETS = $(addprefix docker-build-, $(DEMO_TARGETS))
.PHONY: $(DOCKER_DEMO_TARGETS)
$(DOCKER_DEMO_TARGETS): NAME=$(@:docker-build-%=%)
$(DOCKER_DEMO_TARGETS):
	docker buildx build -t $(DOCKER_REGISTRY)/$(NAME):$(DOCKER_TAG) --secret id=signingkey,src=$(SIGNING_KEY) --target $(NAME) .

build: bin_folder $(DEMO_BUILD_TARGETS)

docker: $(DOCKER_DEMO_TARGETS)

clean:
	rm -r ./app/bin

clean-docker:
	docker rmi $(DOCKER_REGISTRY)/bookbuyer:$(DOCKER_TAG) $(DOCKER_REGISTRY)/bookthief:$(DOCKER_TAG) $(DOCKER_REGISTRY)/bookstore:$(DOCKER_TAG) $(DOCKER_REGISTRY)/bookwarehouse:$(DOCKER_TAG)
