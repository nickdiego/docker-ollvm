DOCKER = docker
IMAGE = nickdiego/ollvm-build

build: Dockerfile
	$(DOCKER) build -t $(IMAGE) .

push: build
	$(DOCKER) push $(IMAGE):latest

all: push

.PHONY: all
