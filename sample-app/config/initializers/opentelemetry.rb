require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

if defined?(Rails::Server)
  OpenTelemetry::SDK.configure do |c|
    c.service_name = 'sample-app'
    if ENV['SERVICE_VERSION']
      c.resource = OpenTelemetry::SDK::Resources::Resource.create(
        ENV['USE_SERVICE_VERSION_AS_ENVIRONMENT_NAME'] ? 'deployment.environment.name' :  'service.version' => ENV['SERVICE_VERSION']
      )
    end
    c.use_all({
      'OpenTelemetry::Instrumentation::Mysql2' => { obfuscation_limit: 10000 },
    })
  end
end
