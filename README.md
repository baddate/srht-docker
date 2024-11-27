# sr.ht-container-compose

The first time sr.ht-container-compose is used, sr.ht sources need to be cloned
locally:

    make init

Then sr.ht can be built and started:

    docker compose watch

Any changes to the sr.ht sources will rebuild and reload sr.ht containers as
needed.

A default admin "root" is created, with password "root" and a personal access
token. A configuration file for [hut] is available in `hut-config`.

The following services are included:

- meta.sr.ht: web frontend at http://127.0.0.1:5000
- todo.sr.ht: web frontend at http://127.0.0.1:5003,
  SMTP server at 127.0.0.1:5903 accepting mails for @todo
- git.sr.ht: web frontend at http://127.0.0.1:5001,
  SSH access at ssh://git@127.0.0.1:5901
- man.sr.ht: web frontend at http://127.0.0.1:5004
- paste.sr.ht: web frontend at http://127.0.0.1:5011
- minio: web frontend at http://127.0.0.1:9001,
  username: minio, password: jIPk1RZ8gdhQwnUL4YtrOAXsFpHvb4Mw8hEwfLq

By default, all services are started. To only start a subset, specify services
of interest as arguments, for instance:

    docker compose up --attach-dependencies todo

To pull changes from all repositories:

    make pull

[hut]: https://sr.ht/~xenrox/hut/
