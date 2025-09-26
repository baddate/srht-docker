#!/bin/sh

docker container stop srht-postgres-1
docker container rm srht-postgres-1
docker volume rm srht_postgres-data
