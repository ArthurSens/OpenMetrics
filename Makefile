BUILD := $(abspath ./bin)

# test-impl tests an OpenMetrics implementation.
#
# To test echo parser:
# make test-impl cmd-parser-text=echo
.PHONY: test-impl
test-impl:
# openmetricstest needs to be built in /src since it requires /src/go.mod
	cd ./src && make openmetricstest
	$(BUILD)/openmetricstest -cmd-parser-text="$(cmd-parser-text)"

.PHONY: prometheus_client_python_parser
prometheus_client_python_parser:
	docker build -t prometheus_client_python_parser:latest                    \
		-f ./tests/implementations/prometheus_client_python_parser/Dockerfile \
		./tests/implementations/prometheus_client_python_parser

# To test github.com/prometheus/client_python parser:
.PHONY: test_prometheus_client_python_parser
test_prometheus_client_python_parser:
	make prometheus_client_python_parser
	make test-impl cmd-parser-text="docker run --rm -i prometheus_client_python_parser:latest"

# To test OpenMetrics validator:
.PHONY: test_open_metrics_validator
test_open_metrics_validator:
	cd ./src && make openmetricsvalidator
	make test-impl cmd-parser-text="./bin/openmetricsvalidator"


.PHONY: proto_go
proto_go: setup
	PATH=$(PWD)/tmp/bin:$$PATH protoc --go_out=go --go_opt=paths=source_relative ./proto/*.proto

.PHONY: setup
setup: $(PROTOC_GEN_GO) $(PROTOC)
	mkdir -p $(BUILD)

.PHONY: clean
clean:
	rm -rf $(BUILD)


####################### Stuff used by fork

PROTOC_VERSION := 3.20.3
PROTOC_GEN_GO_VERSION := v1.30.0

# There are no protobuf releases for Darwin ARM so for
# now we always use the x86_64 release through Rosetta.
UNAME_OS := $(shell uname -s)
UNAME_ARCH := $(shell uname -m)
ifeq ($(UNAME_OS),Darwin)
PROTOC_OS := osx
PROTOC_ARCH := x86_64
endif
ifeq ($(UNAME_OS),Linux)
PROTOC_OS = linux
PROTOC_ARCH := $(UNAME_ARCH)
endif
PROTOC := tmp/versions/protoc/$(PROTOC_VERSION)
PROTOC_BIN := tmp/bin/protoc
PROTOC_INCLUDE := tmp/include/google
$(PROTOC):
	@if ! command -v curl >/dev/null 2>/dev/null; then echo "error: curl must be installed"  >&2; exit 1; fi
	@if ! command -v unzip >/dev/null 2>/dev/null; then echo "error: unzip must be installed"  >&2; exit 1; fi
	@rm -f $(PROTOC_BIN)
	@rm -rf $(PROTOC_INCLUDE)
	@mkdir -p $(dir $(PROTOC_BIN)) $(dir $(PROTOC_INCLUDE))
	$(eval PROTOC_TMP := $(shell mktemp -d))
	cd $(PROTOC_TMP); curl -sSL https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-$(PROTOC_OS)-$(PROTOC_ARCH).zip -o protoc.zip
	cd $(PROTOC_TMP); unzip protoc.zip && mv bin/protoc $(PWD)/$(PROTOC_BIN) && mv include/google $(PWD)/$(PROTOC_INCLUDE)
	@rm -rf $(PROTOC_TMP)
	@rm -rf $(dir $(PROTOC))
	@mkdir -p $(dir $(PROTOC))
	@touch $(PROTOC)

PROTOC_GEN_GO := tmp/versions/protoc-gen-go/$(PROTOC_GEN_GO_VERSION)
PROTOC_GEN_GO_BIN := tmp/bin/protoc-gen-go
$(PROTOC_GEN_GO):
	@rm -f $(PROTOC_GEN_GO_BIN)
	@mkdir -p $(dir $(PROTOC_GEN_GO_BIN))
	$(eval PROTOC_GEN_GO_TMP := $(shell mktemp -d))
	cd $(PROTOC_GEN_GO_TMP); GOBIN=$(PWD)/$(dir $(PROTOC_GEN_GO_BIN)) go install google.golang.org/protobuf/cmd/protoc-gen-go@$(PROTOC_GEN_GO_VERSION)
	@rm -rf $(PROTOC_GEN_GO_TMP)
	@rm -rf $(dir $(PROTOC_GEN_GO))
	@mkdir -p $(dir $(PROTOC_GEN_GO))
	@touch $(PROTOC_GEN_GO)
