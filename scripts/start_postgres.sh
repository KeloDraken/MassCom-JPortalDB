#!/usr/bin/sh

docker run --rm --name postgres -e POSTGRES_PASSWORD=magic_password -p 5432:5432 postgres