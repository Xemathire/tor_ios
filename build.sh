#!/bin/bash

if [ "$1" == "--noverify" ]; then
	./build-libssl.sh --noverify && \
	./build-libevent.sh --noverify && \
	./build-tor.sh --noverify
else
	./build-libssl.sh && \
	./build-libevent.sh && \
	./build-tor.sh
fi