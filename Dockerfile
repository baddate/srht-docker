FROM docker.io/alpine:3.22 AS srht-core
RUN mkdir -p /var/cache/apk && ln -s /var/cache/apk /etc/apk/cache
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add curl
RUN echo "https://mirror.sr.ht/alpine/v3.22/sr.ht" >>/etc/apk/repositories
RUN curl -o /etc/apk/keys/alpine@sr.ht.rsa.pub 'https://mirror.sr.ht/alpine/alpine%40sr.ht.rsa.pub'
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add py3-srht ariadne-codegen make
ADD core.sr.ht /src/core.sr.ht/
RUN make -C /src/core.sr.ht/ install
ENV SRHT_PATH=/src/core.sr.ht/srht
ENV PYTHONPATH=/src/core.sr.ht
ENV PATH="${PATH}:/src/core.sr.ht"

FROM srht-core AS srht-core-build
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add go make sassc minify

FROM srht-core-build AS srht-meta-build
ADD meta.sr.ht /src/meta.sr.ht/
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/root/go/pkg/mod \
	cd /src/meta.sr.ht && make

FROM srht-core-build AS srht-todo-build
ADD todo.sr.ht /src/todo.sr.ht/
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/root/go/pkg/mod \
	cd /src/todo.sr.ht && make

FROM srht-core-build AS srht-git-build
ADD git.sr.ht /src/git.sr.ht/
ADD scm.sr.ht /src/scm.sr.ht/
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/root/go/pkg/mod \
	cd /src/git.sr.ht && make

FROM srht-core-build AS srht-man-build
ADD man.sr.ht /src/man.sr.ht/
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/root/go/pkg/mod \
	cd /src/man.sr.ht && make

FROM srht-core-build AS srht-paste-build
ADD paste.sr.ht /src/paste.sr.ht/
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/root/go/pkg/mod \
	cd /src/paste.sr.ht && make

FROM srht-core-build AS srht-hub-build
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add hg.sr.ht-dev builds.sr.ht-dev
RUN cp /usr/share/sourcehut/hg.sr.ht.graphqls /usr/local/share/sourcehut/hg.sr.ht.graphqls
RUN cp /usr/share/sourcehut/builds.sr.ht.graphqls /usr/local/share/sourcehut/builds.sr.ht.graphqls
ADD git.sr.ht/api/graph/schema.graphqls /usr/local/share/sourcehut/git.sr.ht.graphqls
ADD lists.sr.ht/api/graph/schema.graphqls /usr/local/share/sourcehut/lists.sr.ht.graphqls
ADD todo.sr.ht/api/graph/schema.graphqls /usr/local/share/sourcehut/todo.sr.ht.graphqls
ADD hub.sr.ht /src/hub.sr.ht/
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/root/go/pkg/mod \
	cd /src/hub.sr.ht && make

FROM srht-core-build AS srht-lists-build
ADD lists.sr.ht /src/lists.sr.ht/
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/root/go/pkg/mod \
	cd /src/lists.sr.ht && make

FROM srht-core AS srht-meta
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add meta.sr.ht
COPY --from=srht-meta-build /src/meta.sr.ht /src/meta.sr.ht
ENV PYTHONPATH="${PYTHONPATH}:/src/meta.sr.ht"
ENV PATH="${PATH}:/src/meta.sr.ht"

FROM srht-core AS srht-todo
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add todo.sr.ht
COPY --from=srht-todo-build /src/todo.sr.ht /src/todo.sr.ht
ENV PYTHONPATH="${PYTHONPATH}:/src/todo.sr.ht"
ENV PATH="${PATH}:/src/todo.sr.ht"

FROM srht-core AS srht-git
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add git.sr.ht sourcehut-ssh openssh
ADD scm.sr.ht /src/scm.sr.ht/
COPY --from=srht-git-build /src/git.sr.ht /src/git.sr.ht
# Create various log files and make them writable to avoid spurious
# messages displayed upon "git clone"
RUN touch /var/log/git.sr.ht-shell /var/log/git.sr.ht-update-hook
RUN chmod 666 /var/log/git.sr.ht-shell /var/log/git.sr.ht-update-hook
RUN passwd -u git # Unlock account to allow SSH login
ENV PYTHONPATH="${PYTHONPATH}:/src/scm.sr.ht:/src/git.sr.ht"
ENV PATH="${PATH}:/src/git.sr.ht"

FROM srht-core AS srht-man
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add man.sr.ht
COPY --from=srht-man-build /src/man.sr.ht /src/man.sr.ht
ENV PYTHONPATH="${PYTHONPATH}:/src/man.sr.ht"
ENV PATH="${PATH}:/src/man.sr.ht"

FROM srht-core AS srht-paste
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add paste.sr.ht
COPY --from=srht-paste-build /src/paste.sr.ht /src/paste.sr.ht
ENV PYTHONPATH="${PYTHONPATH}:/src/paste.sr.ht"
ENV PATH="${PATH}:/src/paste.sr.ht"

FROM srht-core AS srht-hub
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add hub.sr.ht
COPY --from=srht-hub-build /src/hub.sr.ht /src/hub.sr.ht
ENV PYTHONPATH="${PYTHONPATH}:/src/hub.sr.ht"
ENV PATH="${PATH}:/src/hub.sr.ht"

FROM srht-core AS srht-lists
RUN --mount=type=cache,target=/var/cache/apk \
	apk -U add lists.sr.ht
COPY --from=srht-lists-build /src/lists.sr.ht /src/lists.sr.ht
ENV PYTHONPATH="${PYTHONPATH}:/src/lists.sr.ht"
ENV PATH="${PATH}:/src/lists.sr.ht"
