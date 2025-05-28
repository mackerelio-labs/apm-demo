require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

if defined?(Rails::Server)
  OpenTelemetry::SDK.configure do |c|
    c.service_name = 'sample-app'
    h = {}
    if ENV['SERVICE_VERSION']
      if ENV['USE_SERVICE_VERSION_AS_ENVIRONMENT_NAME'] && ENV['USE_SERVICE_VERSION_AS_ENVIRONMENT_NAME'] != 'false'
        h['deployment.environment.name'] = ENV['SERVICE_VERSION']
      else
        h['service.version'] = ENV['SERVICE_VERSION']
      end
    end
    if ENV['ENVIRONMENT_NAME']
      h['deployment.environment.name'] = ENV['ENVIRONMENT_NAME']
    end
    if h
      c.resource = OpenTelemetry::SDK::Resources::Resource.create(h)
    end
    c.use_all({
      'OpenTelemetry::Instrumentation::Mysql2' => { obfuscation_limit: 10000 },
    })
  end
end
