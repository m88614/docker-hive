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
