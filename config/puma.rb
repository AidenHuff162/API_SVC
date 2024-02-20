unless ['test', 'development'].include?(ENV['RAILS_ENV'])
  require 'concurrent'
  require 'puma_worker_killer'
  require 'puma/daemon'

  app_path = '/home/deployer/www/sapling'

  directory "#{app_path}/current"

  rackup "#{app_path}/current/config.ru"

  pidfile "#{app_path}/shared/tmp/pids/puma.pid"

  state_path "#{app_path}/shared/tmp/puma.state"

  # Number of workers should match with number of CPU cores.
  # Number of threads should match 4x of workers.
  # file:/etc/profile.d/sapling-app.sh
  #   export PUMA_WORKERS=$(nproc)
  #   export PUMA_MAX_THREADS=$(expr 4 \* $(nproc))
  workers Concurrent.processor_count || 2
  threads 1, Concurrent.processor_count * 2 || 4

  daemonize

  bind "unix:#{app_path}/shared/tmp/sockets/puma.sock"

  ### Adding stdout redirect for puma worker killer
  stdout_redirect "#{app_path}/shared/log/puma.stdout.log", "#{app_path}/shared/log/puma.stderr.log", true
  ################################################

  preload_app!

  on_worker_boot do
    Rails.configuration.ld_client = LaunchDarkly::LDClient.new(ENV['LAUNCH_DARKLY_KEY'])
  end


  ##### Config related to puma worker killer START##################
  mem_in_kb = %x[cat /proc/meminfo | grep MemTotal | awk '{print $2}']
  mem_in_mb  = mem_in_kb.to_i / 1024
  puts "Memory (KB):: #{mem_in_kb.to_i} \nMemory (MB):: #{mem_in_mb}"

  before_fork do
    PumaWorkerKiller.config do |config|
      config.ram           = mem_in_mb # mb
      config.frequency     = 5    # seconds
      config.percent_usage = 0.65 ## setting 65% of total mem
      config.rolling_restart_frequency = 24 * 3600 # 24 hours in seconds, or 12.hours if using Rails
      config.pre_term = -> (worker) { puts "Worker #{worker.inspect} being killed" }
      #config.reaper_status_logs = false ## for disabling reaper

    end
    PumaWorkerKiller.start
  end
  ##### Config related to puma worker killer END ##################
end

