
# Disable make's implicit rules, which are not useful for golang, and slow down the build
# considerably.
.SUFFIXES:

all: bin/confd

GO_BUILD_CONTAINER?=calico/go-build:v0.4

# All go files.
GO_FILES:=$(shell find . -type f -name '*.go')

# Figure out the users UID.  This is needed to run docker containers
# as the current user and ensure that files built inside containers are
# owned by the current user.
MY_UID:=$(shell id -u)

DOCKER_GO_BUILD := mkdir -p .go-pkg-cache && \
                   docker run --rm \
                              --net=host \
                              $(EXTRA_DOCKER_ARGS) \
                              -e LOCAL_USER_ID=$(MY_UID) \
                              -v ${CURDIR}:/go/src/github.com/kelseyhightower/confd:rw \
                              -v ${CURDIR}/.go-pkg-cache:/go/pkg:rw \
                              -w /go/src/github.com/kelseyhightower/confd \
                              $(GO_BUILD_CONTAINER)

# Update the vendored dependencies with the latest upstream versions matching
# our glide.yaml.  If there are any changes, this updates glide.lock
# as a side effect.  Unless you're adding/updating a dependency, you probably
# want to use the vendor target to install the versions from glide.lock.
.PHONY: update-vendor
update-vendor:
	mkdir -p $$HOME/.glide
	$(DOCKER_GO_BUILD) glide up --strip-vendor
	touch vendor/.up-to-date

# vendor is a shortcut for force rebuilding the go vendor directory.
.PHONY: vendor
vendor vendor/.up-to-date: glide.lock
	mkdir -p $$HOME/.glide
	$(DOCKER_GO_BUILD) glide install --strip-vendor
	touch vendor/.up-to-date

bin/confd: $(GO_FILES) vendor/.up-to-date
	@echo Building confd...
	mkdir -p bin
	$(DOCKER_GO_BUILD) \
	    sh -c 'go build -v -i -o $@ "github.com/kelseyhightower/confd" && \
               ( ldd bin/confd 2>&1 | grep -q "Not a valid dynamic program" || \
	             ( echo "Error: bin/confd was not statically linked"; false ) )'