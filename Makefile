DOCKER = docker
IMAGE = nickdiego/ollvm

build: Dockerfile
	$(DOCKER) build -t $(IMAGE) .

all: build

.PHONY: all
