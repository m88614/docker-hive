Vagrant.configure("2") do |config|
  config.vm.box = "local/hashistack"
  config.vm.network "private_network", ip: "10.0.3.10"

  # Hashicorp consul ui
  config.vm.network "forwarded_port", guest: 8500, host: 8500, host_ip: "127.0.0.1"

  # Hashicorp nomad ui
  config.vm.network "forwarded_port", guest: 4646, host: 4646, host_ip: "127.0.0.1"

  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
    vb.memory = 8000
    vb.cpus = 8
  end
  config.vm.provision "ansible" do |ansible|
      ansible.playbook = "./test/setup_jobs.yml"
  end

end
