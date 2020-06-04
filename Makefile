branch = $(shell git rev-parse --abbrev-ref HEAD)

.ONESHELL .PHONY: build install_mac
.DEFAULT_GOAL := build

custom_ca:
ifdef CUSTOM_CA
	cp -rf $(CUSTOM_CA)/* ca_certificates/ || cp -f $(CUSTOM_CA) ca_certificates/
endif

build: custom_ca
	docker build . -t local/hive:$(branch)
	docker tag  local/hive:$(branch) local/hive:latest

install_mac: install_vagrant_mac install_ansible_mac install_virtualbox_mac

install_ansible_mac:
	brew cask install ansible

install_vagrant_mac:
	brew cask install vagrant

install_virtualbox_mac:
	brew cask install virtualbox

install_virtualbox:
	curl -L -s https://download.virtualbox.org/virtualbox/${VIRTUALBOX_VERSION}/SHA256SUMS -o /var/tmp/virtualbox_SHA256SUMS
	curl -L -s https://download.virtualbox.org/virtualbox/${VIRTUALBOX_VERSION}/${VIRTUALBOX_FULLNAME} -o /var/tmp/${VIRTUALBOX_FULLNAME}
	(cd /var/tmp; sha256sum --ignore-missing -c virtualbox_SHA256SUMS)
	sudo apt-get install -y gcc make perl
	sudo dpkg -i /var/tmp/${VIRTUALBOX_FULLNAME}
	sudo apt --fix-broken install -y
	rm /var/tmp/virtualbox_SHA256SUMS /var/tmp/${VIRTUALBOX_FULLNAME}

install_vagrant:
	curl -L -s https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_SHA256SUMS -o /var/tmp/vagrant_SHA256SUMS
	curl -L -s https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_SHA256SUMS.sig -o /var/tmp/vagrant_SHA256SUMS.sig
	gpg --verify /var/tmp/vagrant_SHA256SUMS.sig /var/tmp/vagrant_SHA256SUMS
	curl -L -s https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb -o /var/tmp/vagrant_${VAGRANT_VERSION}_x86_64.deb
	(cd /var/tmp; sha256sum --ignore-missing -c vagrant_SHA256SUMS)
	sudo dpkg -i /var/tmp/vagrant_${VAGRANT_VERSION}_x86_64.deb
	SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt vagrant plugin install vagrant-certificates
	rm /var/tmp/vagrant_SHA256SUMS /var/tmp/vagrant_SHA256SUMS.sig /var/tmp/vagrant_${VAGRANT_VERSION}_x86_64.deb

install_ansible:
	curl -L -s https://releases.ansible.com/ansible/${ANSIBLE_VERSION}/ansible_${ANSIBLE_VERSION}_SHA256SUMS -o /var/tmp/ansible_SHA256SUMS
	curl -L -s https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_SHA256SUMS.sig -o /var/tmp/vagrant_SHA256SUMS.sig
	gpg --verify /var/tmp/vagrant_SHA256SUMS.sig /var/tmp/vagrant_SHA256SUMS
	curl -L -s https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb -o /var/tmp/vagrant_${VAGRANT_VERSION}_x86_64.deb
	(cd /var/tmp; sha256sum --ignore-missing -c vagrant_SHA256SUMS)
	sudo dpkg -i /var/tmp/vagrant_${VAGRANT_VERSION}_x86_64.deb
	SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt vagrant plugin install vagrant-certificates
	rm /var/tmp/vagrant_SHA256SUMS /var/tmp/vagrant_SHA256SUMS.sig /var/tmp/vagrant_${VAGRANT_VERSION}_x86_64.deb
