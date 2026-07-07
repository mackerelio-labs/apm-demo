require 'sinatra/base'
require 'json'
require 'digest'
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/sinatra'
require 'opentelemetry/instrumentation/rack'
require 'opentelemetry-logs-sdk'
require 'opentelemetry/exporter/otlp_logs'

OpenTelemetry::SDK.configure do |c|
  c.use 'OpenTelemetry::Instrumentation::Rack'
  c.use 'OpenTelemetry::Instrumentation::Sinatra'
end

OTEL_LOGGER_PROVIDER = OpenTelemetry::SDK::Logs::LoggerProvider.new(
  resource: OpenTelemetry.tracer_provider.resource
)
OTEL_LOGGER_PROVIDER.add_log_record_processor(
  OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(
    OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new
  )
)
OTEL_LOGGER = OTEL_LOGGER_PROVIDER.logger(name: 'product-info-api')

class OtelAccessLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, body = @app.call(env)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)

    span_context = OpenTelemetry::Trace.current_span.context
    severity = status.to_i >= 500 ? OpenTelemetry::Logs::SeverityNumber::SEVERITY_NUMBER_ERROR : OpenTelemetry::Logs::SeverityNumber::SEVERITY_NUMBER_INFO

    OTEL_LOGGER.on_emit(
      body: "#{env['REQUEST_METHOD']} #{env['PATH_INFO']} #{status} #{duration_ms}ms",
      severity_number: severity,
      severity_text: severity == OpenTelemetry::Logs::SeverityNumber::SEVERITY_NUMBER_ERROR ? 'ERROR' : 'INFO',
      attributes: {
        'http.request.method' => env['REQUEST_METHOD'],
        'url.path' => env['PATH_INFO'],
        'http.response.status_code' => status.to_i,
        'duration_ms' => duration_ms,
      },
      trace_id: span_context.trace_id,
      span_id: span_context.span_id,
      trace_flags: span_context.trace_flags,
    )

    [status, headers, body]
  end
end

class NetworkLatencySimulator
  def initialize(app, min: 0.05, max: 0.3)
    @app = app
    @min = min
    @max = max
  end

  def call(env)
    sleep(rand(@min..@max))
    @app.call(env)
  end
end

class ProductInfoAPI < Sinatra::Base
  use OtelAccessLogger
  use NetworkLatencySimulator, min: 0.05, max: 0.3
  set :host_authorization, permitted_hosts: []

  TRACER = OpenTelemetry.tracer_provider.tracer('product-info-api')

  get '/products/:id' do
    content_type :json
    product_id = params[:id]

    TRACER.in_span('load product info', kind: :server) do |span|
      hv = Digest::SHA256.hexdigest(product_id)
      v = hv.reverse[0, 2].to_i(16)

      warehouses = %w[Tokyo Osaka Fukuoka Sapporo Nagoya]
      warehouse = warehouses[v % 5]
      delivery_days = (v % 5) + 1

      span.set_attribute('product.id', product_id)
      span.set_attribute('warehouse.region', warehouse)

      sleep((v % 10 + 1) * 0.15)

      if warehouse == 'Sapporo'
        sleep(2)
        err = IOError.new("connection timed out: inventory-backend")
        span.record_exception(err)
        span.status = OpenTelemetry::Trace::Status.error(err.message)
        halt 504, { error: 'connection timed out: inventory-backend' }.to_json
      end

      {
        product_id: product_id,
        availability: v < 60 ? 'low_stock' : 'in_stock',
        warehouse: warehouse,
        estimated_delivery: "#{delivery_days}-#{delivery_days + 2} days",
      }.to_json
    end
  end

  get '/health' do
    content_type :json
    { status: 'ok' }.to_json
  end
end
