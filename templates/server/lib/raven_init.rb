require 'raven'

Raven.configure do |config|
  config.should_capture = ->(_) { !!ENV['SENTRY_DSN'] }
  config.open_timeout = (ENV['RAVEN_OPEN_TIMEOUT'] || 3).to_i
  config.timeout = (ENV['RAVEN_TIMEOUT'] || 3).to_i
end

Raven.capture
