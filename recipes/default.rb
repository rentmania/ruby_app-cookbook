node['ruby_apps'].each do |app, site|
  apps_root = site['root']

  site['environments'].each do |env_name, env|
    app_name = "#{app}_#{env_name}"
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
        port: env['port'],
        www_redirect: env['www_redirect']
      )

      notifies :reload, 'service[nginx]', :immediately
    end

    link "/etc/nginx/sites-enabled/#{app_name}" do
      to "/etc/nginx/sites-available/#{app_name}"
    end

    if site['sidekiq']
      template "/etc/systemd/system/sidekiq_#{app_name}.service" do
        source 'sidekiq_systemd.erb'
        variables(
          app_name: app_name,
          app_root: app_root,
          app_shared: app_shared,
          env: env_name
        )
      end
    end

    if env['db']
      shared_configs = "#{app_shared}/config"
      [app_root, app_shared, shared_configs].each do |dir|
        directory dir do
          mode '0755'
          action :create
        end
      end

      template "#{shared_configs}/database.yml" do
        source 'database.yml.erb'
        variables(
          database: env['db']['database'],
          user: env['db']['name'],
          password: env['db']['password'],
        )
      end
    end
  end
end
