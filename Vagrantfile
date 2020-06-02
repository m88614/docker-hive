Vagrant.configure("2") do |config|
  config.vm.box = "fredrikhgrelland/hashistack"
  config.vm.network "private_network", ip: "10.0.3.10"

  # Hashicorp consul ui
  config.vm.network "forwarded_port", guest: 8500, host: 8500, host_ip: "127.0.0.1"

  # Hashicorp nomad ui
  config.vm.network "forwarded_port", guest: 4646, host: 4646, host_ip: "127.0.0.1"

  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.memory = 2048
  end
  config.vm.provision "ansible" do |ansible|
      ansible.playbook = "setup_hive.yml"
  end

end
