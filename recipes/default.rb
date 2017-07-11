node['ruby_apps'].each do |site|
  apps_root = site['root']

  site['environments'].each do |env|
    env_name = env['name']
    app_name = "#{site['name']}_#{env_name}"
    app_root = "#{apps_root}/#{app_name}"
    app_shared = "#{app_root}/shared"

    template "/etc/systemd/system/unicorn_#{app_name}.service" do
      source 'unicorn_systemd.erb'
      variables(
        app_name: app_name,
        app_root: app_root,
        app_shared: app_shared,
        env: env_name
      )
    end

    # unicorn nginx config
    template "/etc/nginx/sites-available/#{app_name}" do
      source "nginx_app.erb"
      variables(
        has_ssl: false,
        prerender_ip: nil,
        prerender_port: nil,
        app_name: app_name,
        domains: env[:domains],
        app_root: app_root,
        app_shared: app_shared,
        port: env['port']
      )

        notifies :reload, 'service[nginx]', :immediately
    end

    link "/etc/nginx/sites-enabled/#{app_name}" do
      to "/etc/nginx/sites-available/#{app_name}"
    end
  end
end
