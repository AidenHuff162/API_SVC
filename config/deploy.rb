lock '3.9.0'

set :application, 'sapling'
set :repo_url, 'git@github.com:sapling-hr/api-svc.git'

set :use_sudo, true
set :deploy_via, :copy
set :keep_releases, 5
set :log_level, :debug
set :pty, false

set :rvm1_ruby_version, 'ruby-2.7.4'
set :rvm_type, :user
set :default_env, { rvm_bin_path: '~/.rvm/bin' , 
  SIDEKIQ_CONCURRENCY: ENV['SIDEKIQ_CONCURRENCY'], 
  SIDEKIQ_PERIODIC_CONCURRENCY: ENV['SIDEKIQ_PERIODIC_CONCURRENCY'], 
  SIDEKIQ_INTEGRATION_PULL_CONCURRENCY: ENV['SIDEKIQ_INTEGRATION_PULL_CONCURRENCY'],
  SIDEKIQ_INTEGRATION_PUSH_CONCURRENCY: ENV['SIDEKIQ_INTEGRATION_PUSH_CONCURRENCY'],
  SIDEKIQ_CUSTOM_TABLE_CONCURRENCY: ENV['SIDEKIQ_CUSTOM_TABLE_CONCURRENCY'],
  SIDEKIQ_MAILER_CONCURRENCY: ENV['SIDEKIQ_MAILER_CONCURRENCY'],
  SIDEKIQ_REPORTING_CONCURRENCY: ENV['SIDEKIQ_REPORTING_CONCURRENCY'],
  SIDEKIQ_USER_BIG__SCHEDULE_REPORTS_CONCURRENCY: ENV['SIDEKIQ_USER_BIG__SCHEDULE_REPORTS_CONCURRENCY'],
  SIDEKIQ_USER_SCHEDULE_REPORTS_CONCURRENCY: ENV['SIDEKIQ_USER_SCHEDULE_REPORTS_CONCURRENCY'],
  SIDEKIQ_WORKFLOW_SCHEDULE_REPORTS_CONCURRENCY: ENV['SIDEKIQ_WORKFLOW_SCHEDULE_REPORTS_CONCURRENCY'],
  SIDEKIQ_USER_REPORTS_CONCURRENCY: ENV['SIDEKIQ_USER_REPORTS_CONCURRENCY']
}
set :rvm1_map_bins, -> { fetch(:rvm_map_bins).to_a.concat(%w{rake gem bundle ruby}).uniq }

set :linked_files, %w{config/bootstrap.yml}
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle}

set :sidekiq_roles, :sidekiq
set :sidekiq_processes, 11
set :sidekiq_options_per_process, [
  "--logfile log/sidekiq.log --config config/sidekiq.yml",
  "--logfile log/sidekiq-mailer.log --config config/sidekiq-mailer.yml",
  "--logfile log/sidekiq-periodic-jobs.log --config config/sidekiq-periodic-jobs.yml",
  "--logfile log/sidekiq-integration-push-jobs.log --config config/sidekiq-integration-push-jobs.yml",
  "--logfile log/sidekiq-integration-pull-jobs.log --config config/sidekiq-integration-pull-jobs.yml",
  "--logfile log/sidekiq-webhook-custom-table-jobs.log --config config/sidekiq-webhook-custom-table-jobs.yml",
  "--logfile log/sidekiq-reporting-jobs.log --config config/sidekiq-reporting-jobs.yml",
  "--logfile log/sidekiq-user-big-report-jobs.log --config config/sidekiq-user-big-report-jobs.yml",
  "--logfile log/sidekiq-user-report-jobs.log --config config/sidekiq-user-report-jobs.yml",
  "--logfile log/sidekiq-workflows-report-jobs.log --config config/sidekiq-workflow-report-jobs.yml",
  "--logfile log/sidekiq-user-schedule-report-jobs.log --config config/sidekiq-user-schedule-report-jobs.yml"
]
set :sidekiq_monit_conf_dir, '/etc/monit/conf.d'
set :sidekiq_monit_use_sudo, true
set :ssh_options, {forward_agent: true}
set :whenever_roles, [:app, :cronjobs, :sidekiq]

after 'deploy:check', 'deploy:setup_manifest'
before 'deploy:assets:precompile', 'deploy:load_translations'
after 'deploy:updated', 'newrelic:notice_deployment'

namespace :deploy do
  desc 'Create manifest.json if not present'
  task :setup_manifest do
    on roles(:web) do
      unless test("[ -f " + shared_path.to_s + "/public/assets/manifest.json ]" )
        execute "touch #{shared_path.to_s}/public/assets/manifest.json"
      end
    end
  end

  desc 'Uploads required config files'
  task :upload_configs do
    on roles(:all) do
      # upload!('config/application.yml', "#{deploy_to}/shared/config/application.yml")
      upload!('config/bootstrap.yml', "#{deploy_to}/shared/config/bootstrap.yml")
      # upload!('config/health_check.yml', "#{deploy_to}/shared/config/health_check.yml")
    end
  end

  desc 'Seeds database'
  task :seed do
    on roles(:app) do
      invoke 'rvm1:hook'
      within "#{fetch(:deploy_to)}/current/" do
        execute :bundle, :exec, :"rails db:seed RAILS_ENV=#{fetch(:stage)}"
      end
    end
  end

  desc 'Load I18n JS translations'
  task :load_translations do
    on roles(:app) do
      invoke!('rvm1:hook')
      within release_path do
        execute :bundle, :exec, :"rails i18n:js:export RAILS_ENV=#{fetch(:stage)}"
        execute :bundle, :exec, :"rails tmp:cache:clear RAILS_ENV=#{fetch(:stage)}"
      end
    end
  end

end

namespace :app do
  desc 'Start application'
  task :start do
    on roles(:app) do
      invoke!('rvm1:hook')
      within "#{fetch(:deploy_to)}/current/" do
        execute :bundle, :exec, :"puma -C config/puma.rb -e #{fetch(:stage)}"
      end
    end
  end

  desc 'Stop application'
  task :stop do
    on roles(:app) do
      invoke!('rvm1:hook')
      within "#{fetch(:deploy_to)}/current/" do
        execute :bundle, :exec, :'pumactl -F config/puma.rb stop'
      end
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app) do
      invoke!('rvm1:hook')
      within "#{fetch(:deploy_to)}/current/" do
        if test("[ -f #{deploy_to}/current/tmp/pids/puma.pid ]")
          execute :bundle, :exec, :'pumactl -F config/puma.rb stop'
        end

        execute :bundle, :exec, :"puma -C config/puma.rb -e #{fetch(:stage)}"
      end
    end
  end
end


