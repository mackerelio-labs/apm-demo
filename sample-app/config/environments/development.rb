require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails dev:cache to toggle Action Controller caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Change to :null_store to avoid any caching.
  config.cache_store = :memory_store

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log
  config.log_level = :info

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  #false化
  config.active_record.verbose_query_logs = false

  # Append comments with runtime information tags to SQL queries in logs.
  #false化
  config.active_record.query_log_tags_enabled = false

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  config.hosts.clear
  log_dest = if ENV["LOG_TO_STDOUT"]
               $stdout
             else
               log_name = if ENV["ENVIRONMENT_NAME"] && ENV["SERVICE_VERSION"]
                            "#{ENV["ENVIRONMENT_NAME"]}-#{ENV["SERVICE_VERSION"]}.log"
                          else
                            "development.log"
                          end
               Rails.root.join("log", log_name)
             end
  logger = ActiveSupport::Logger.new(log_dest, 1, 10 * 1024 * 1024)
  logger.formatter = proc do |severity, time, _progname, msg|
    entry = { "timestamp" => time.utc.strftime("%Y-%m-%dT%H:%M:%S.%3NZ"), "severity" => severity }

    case msg
    when Hash
      entry.merge!(msg.stringify_keys)
    when Exception
      entry["message"] = msg.message
      entry["backtrace"] = (msg.backtrace || []).first(30).join("\n")
    when String
      # DebugExceptions middleware outputs "  \nClassName (msg):\n..." — lograge already covers this
      next "" if msg.start_with?("  \n")
      entry["message"] = msg
    else
      entry["message"] = msg.to_s
    end

    span = OpenTelemetry::Trace.current_span
    if span.context.valid?
      entry["trace_id"] = span.context.hex_trace_id
      entry["span_id"]  = span.context.hex_span_id
    end

    "#{entry.to_json}\n"
  end
  config.logger = logger

  config.lograge.enabled = true
  config.lograge.base_controller_class = "ActionController::API"
  config.lograge.keep_original_rails_log = false
  config.lograge.formatter = Lograge::Formatters::Raw.new

  config.lograge.custom_options = lambda do |event|
    status = event.payload[:status].to_i
    data = {}

    if event.payload[:exception_object] || status >= 500
      data[:severity] = "ERROR"
    elsif status >= 400
      data[:severity] = "WARN"
    end

    error = event.payload[:exception_object]
    if error
      data[:error_class] = error.class.name
      data[:error_message] = error.message
      data[:backtrace] = Rails.backtrace_cleaner.clean(error.backtrace || []).first(30).join("\n")
    elsif event.payload[:exception]
      data[:error_class], data[:error_message] = event.payload[:exception]
    end

    data
  end
end
