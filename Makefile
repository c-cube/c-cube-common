build-crush-docker:
	docker build -f deps/dockerfile.crush -t crush-docker .

include deps/Makefile.ci
