rails_env = ENV['RAILS_ENV'] || 'production'

# The rule of thumb is to use 1 worker per processor core available,
# however since we'll be hosting many apps on this server,
# we need to take a less aggressive approach
worker_processes 2

# We deploy with capistrano, so "current" links to root dir of current release
directory = "/home/bikecollectives/#{ENV['RAILS_ENV']}"
port = 8082 + (ENV['RAILS_ENV'] == 'preview' ? 1 : 0)

working_directory directory

# Listen on unix socket
listen "127.0.0.1:#{port}", :backlog => 64

pid "/home/unicorn/bikecollectives/#{ENV['RAILS_ENV']}.pid"

stderr_path "#{directory}/log/unicorn.log"
stdout_path "#{directory}/log/unicorn.log"
