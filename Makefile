repos = core.sr.ht meta.sr.ht todo.sr.ht scm.sr.ht git.sr.ht man.sr.ht paste.sr.ht hub.sr.ht

.PHONY: init
.ONESHELL:
init:
	@
	for repo in ${repos}; do
		[ -e $$repo ] || git clone --recurse-submodules https://git.sr.ht/~sircmpwn/$$repo
		git -C $$repo config sendemail.to '~sircmpwn/sr.ht-dev@lists.sr.ht'
		git -C $$repo config format.subjectPrefix "PATCH $$repo"
	done

.PRONY: pull
.ONESHELL:
pull:
	@
	for repo in ${repos}; do
		git -C $$repo pull
	done

git-sshd/ssh_host_rsa_key:
	ssh-keygen -f git-sshd/ssh_host_rsa_key -N '' -C 'git-ssh' -t rsa -b 4096
git-sshd/ssh_host_ed25519_key:
	ssh-keygen -f git-sshd/ssh_host_ed25519_key -N '' -C 'git-ssh' -t ed25519
