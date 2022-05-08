# download cadvisor bin
cadvisor_bin_url = node['hops']['cadvisor']['download-url']
bin_name = File.basename(cadvisor_bin_url)
cadvisor_bin = "#{node['hops']['sbin_dir']}/#{bin_name}"

remote_file cadvisor_bin do
  source cadvisor_bin_url
  owner "root"
  mode "0644"
  action :create_if_missing
end

link "#{node['hops']['sbin_dir']}/cadvisor" do
  owner "root"
  to "#{cadvisor_bin}"
end

case node['platform_family']
when "rhel"
  systemd_script = "/usr/lib/systemd/system/cAdvisor.service"
else
  systemd_script = "/lib/systemd/system/cAdvisor.service"
end

service "cadvisor" do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

template systemd_script do
  source "cadvisor.service.erb"
  owner "root"
  group "root"
  mode 0664
  if node['services']['enabled'] == "true"
    notifies :enable, "service[cadvisor]"
  end
  notifies :restart, "service[cadvisor]"
end

kagent_config "cadvisor" do
  action :systemd_reload
end

if node['kagent']['enabled'] == "true"
  kagent_config "cadvisor" do
    service "cadvisor"
    restart_agent false
  end
end

if exists_local('consul', 'master') or exists_local('consul', 'slave')
  # Register cAdvisor with Consul
  consul_service "Registering cAdvisor with Consul" do
    service_definition "cadvisor-consul.hcl.erb"
    reload_consul false
    action :register
  end
end
