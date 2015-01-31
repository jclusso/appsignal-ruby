module Appsignal
  class Transaction
    HTTP_REQUEST   = 'http_request'.freeze
    BACKGROUND_JOB = 'background_job'.freeze

    # Based on what Rails uses + some variables we'd like to show
    ENV_METHODS = %w(CONTENT_LENGTH AUTH_TYPE GATEWAY_INTERFACE
    PATH_TRANSLATED REMOTE_HOST REMOTE_IDENT REMOTE_USER REMOTE_ADDR
    REQUEST_METHOD SERVER_NAME SERVER_PORT SERVER_PROTOCOL REQUEST_URI PATH_INFO

    HTTP_X_REQUEST_START HTTP_X_MIDDLEWARE_START HTTP_X_QUEUE_START
    HTTP_X_QUEUE_TIME HTTP_X_HEROKU_QUEUE_WAIT_TIME HTTP_X_APPLICATION_START
    HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE
    HTTP_CACHE_CONTROL HTTP_CONNECTION HTTP_USER_AGENT HTTP_FROM HTTP_NEGOTIATE
    HTTP_PRAGMA HTTP_REFERER HTTP_X_FORWARDED_FOR HTTP_CLIENT_IP).freeze

    class << self
      def create(request_id, env)
        Appsignal.logger.debug("Creating transaction: #{request_id}")
        Appsignal::Native.start_transaction(request_id)
        Thread.current[:appsignal_transaction] = Appsignal::Transaction.new(request_id, env)
      end

      def current
        Thread.current[:appsignal_transaction]
      end

      def complete_current!
        if current
          Appsignal::Native.finish_transaction(current.request_id)
          Thread.current[:appsignal_transaction] = nil
        else
          Appsignal.logger.error('Trying to complete current, but no transaction present')
        end
      end
    end

    attr_reader :request_id, :root_event_payload, :action, :exception, :env, :fullpath, :tags,
                :kind, :queue_start, :time

    def initialize(request_id, env)
      @request_id = request_id
      @env        = env
      @tags       = {}
    end

    def request
      @request ||= ::Rack::Request.new(env)
    end

    def set_tags(given_tags={})
      @tags.merge!(given_tags)
    end

    def set_root_event(name, payload)
      @root_event_payload = payload
      if name.start_with?(Subscriber::PROCESS_ACTION_PREFIX)
        @action = "#{@root_event_payload[:controller]}##{@root_event_payload[:action]}"
        @kind = HTTP_REQUEST
        set_http_queue_start
      elsif name.start_with?(Subscriber::PERFORM_JOB_PREFIX)
        @action = "#{@root_event_payload[:class]}##{@root_event_payload[:method]}"
        @kind = BACKGROUND_JOB
        set_background_queue_start
      end
      Appsignal::Native.set_transaction_metadata(
        request_id,
        action,
        kind,
        0
      )
    end

    def set_exception(exception)
      @time = Time.now.to_i
      @exception = exception
      Appsignal::Native.set_exception_for_transaction(
        request_id,
        exception_hash.to_json,
        'json'
      )
    end

    def exception?
      !! exception
    end

    def exception_hash
      return unless exception
      {
        :action         => action,
        :time           => time,
        :kind           => kind,
        :overview       => overview,
        :params         => sanitized_params,
        :environment    => sanitized_environment,
        :session_data   => sanitized_session_data,
        :tags           => sanitized_tags,
        :exception      => {
          :exception => exception.class.name,
          :message   => exception.message,
          :backtrace => cleaned_backtrace
        }
      }
    end

    protected

      def set_background_queue_start
        queue_start = root_event_payload[:queue_start]
        return unless queue_start
        Appsignal.logger.debug("Setting background queue start: #{queue_start}")
        @queue_start = queue_start.to_f
      end

      def set_http_queue_start
        return unless env
        env_var = env['HTTP_X_QUEUE_START'] || env['HTTP_X_REQUEST_START']
        if env_var
          Appsignal.logger.debug("Setting http queue start: #{env_var}")
          value = env_var.tr('^0-9', '')
          unless value.empty?
            @queue_start = value.to_f / 1000.0
          end
        end
      end

      def queue_duration
        return unless queue_start && queue_start > 0
        time - queue_start
      end

      def overview
        return unless root_event_payload
        {
          :path           => root_event_payload[:path],
          :request_format => root_event_payload[:request_format],
          :request_method => root_event_payload[:request_method]
        }
      end

      def sanitized_params
        return unless root_event_payload
        Appsignal::ParamsSanitizer.sanitize(root_event_payload[:params])
      end

      def sanitized_environment
        return unless env
        {}.tap do |out|
          ENV_METHODS.each do |key|
            out[key] = env[key] if env[key]
          end
        end
      end

      def sanitized_session_data
        return if Appsignal.config[:skip_session_data] || !env
        Appsignal::ParamsSanitizer.sanitize(request.session.to_hash)
      end

      # Only keep tags if they meet the following criteria:
      # * Key is a symbol or string with less then 100 chars
      # * Value is a symbol or string with less then 100 chars
      # * Value is an integer
      def sanitized_tags
        @tags.select do |k, v|
          (k.is_a?(Symbol) || k.is_a?(String) && k.length <= 100) &&
          (((v.is_a?(Symbol) || v.is_a?(String)) && v.length <= 100) || (v.is_a?(Integer)))
        end
      end

      def cleaned_backtrace
        return unless exception && exception.backtrace.is_a?(Array)
        if defined?(::Rails)
          ::Rails.backtrace_cleaner.clean(exception.backtrace, nil)
        else
          exception.backtrace
        end
      end
  end
end
