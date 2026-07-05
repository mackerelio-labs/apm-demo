require "active_support/core_ext/integer/time"
require "json"

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
  # config.logger = ActiveSupport::Logger.new(STDOUT)
  development_logger = ActiveSupport::Logger.new(
    Rails.root.join('log', 'development.log'),
    1,                  # 保持する世代数
    10 * 1024 * 1024    # 1ファイルあたりの最大サイズ
  )
  development_logger.formatter = proc do |severity, time, _progname, msg|
    base = {
      "timestamp" => time.utc.strftime("%Y-%m-%dT%H:%M:%S.%3NZ")
    }

    raw = case msg
          when String
            msg
          when Exception
            [msg.message, *(msg.backtrace || [])].join("\n")
          else
            msg.inspect
          end

    # Keep request summary JSON logs, but drop noisy debug SQL logs.
    next "" if severity == "DEBUG"

    # Drop duplicated multiline exception output; lograge already emits exception details.
    if severity == "ERROR" && raw.include?("Error (") && raw.include?("\napp/")
      next ""
    end

    candidate = raw.lstrip
    if candidate.start_with?("{")
      begin
        parsed = JSON.parse(candidate)
        if parsed.is_a?(Hash)
          "#{base.merge(parsed).to_json}\n"
        else
          "#{base.merge("severity" => severity, "message" => raw).to_json}\n"
        end
      rescue JSON::ParserError
        "#{base.merge("severity" => severity, "message" => raw).to_json}\n"
      end
    else
      "#{base.merge("severity" => severity, "message" => raw).to_json}\n"
    end
  end
  config.logger = development_logger

  config.lograge.enabled = true
  config.lograge.base_controller_class = "ActionController::API"
  config.lograge.keep_original_rails_log = false
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    status = event.payload[:status].to_i
    data = {
      severity: if event.payload[:exception_object] || status >= 500
                  "ERROR"
                elsif status >= 400
                  "WARN"
                else
                  "INFO"
                end
    }
    current_span = OpenTelemetry::Trace.current_span
    if current_span.context.valid?
      data[:trace_id] = current_span.context.hex_trace_id
      data[:span_id] = current_span.context.hex_span_id
    end

    error = event.payload[:exception_object]
    if error
      data[:error_class] = error.class.name
      data[:error_message] = error.message
      cleaned = Rails.backtrace_cleaner.clean(error.backtrace || [])
      data[:backtrace] = cleaned.first(30).join("\n")
    elsif event.payload[:exception]
      data[:error_class] = event.payload[:exception][0]
      data[:error_message] = event.payload[:exception][1]
    end

    data
  end
end
