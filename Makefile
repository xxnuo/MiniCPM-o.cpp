VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/projects/work/minicpm-o.cpp
DOCKER_REGISTRY := registry.lazycat.cloud/x/minicpm-o.cpp

init-gpu:
	ssh -t $(REMOTE) "sudo ip route add default via 192.168.1.202"

sync-from-gpu:
	rsync -arvzlt --exclude-from=.rsyncignore $(REMOTE):$(REMOTE_PATH)/ ./

sync-to-gpu:
	ssh -t $(REMOTE) "mkdir -p $(REMOTE_PATH)"
	rsync -arvzlt --exclude-from=.rsyncignore ./ $(REMOTE):$(REMOTE_PATH)

sync-clean:
	ssh -t $(REMOTE) "rm -rf $(REMOTE_PATH)"

builder: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
	docker run -it --rm \
	--name mcocpp-builder \
	-v $(REMOTE_PATH)/:/opt/minicpm-o.cpp \
	--network=host \
	vllm:r36.4.tegra-aarch64-cu126-22.04 \
	bash"

build:
	pip install scikit-build-core pybind11
	python -m build --wheel --no-isolation

cp:
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		rm -r ./dist && \
		mkdir -p ./dist && \
		docker cp mcocpp-builder:/opt/minicpm-o.cpp/dist/ ./dist/
