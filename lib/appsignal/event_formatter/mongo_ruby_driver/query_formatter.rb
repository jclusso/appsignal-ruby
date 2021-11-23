# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module MongoRubyDriver
      class QueryFormatter
        ALLOWED = {
          "find" => {
            "find"   => :allow,
            "filter" => :sanitize_document
          },
          "count" => {
            "count" => :allow,
            "query" => :sanitize_document
          },
          "distinct" => {
            "distinct" => :allow,
            "key"      => :allow,
            "query"    => :sanitize_document
          },
          "insert" => {
            "insert"    => :allow,
            "documents" => :deny_array,
            "ordered"   => :allow
          },
          "update" => {
            "update"  => :allow,
            "updates" => :sanitize_bulk,
            "ordered" => :allow
          },
          "findandmodify" => {
            "findandmodify" => :allow,
            "query"         => :sanitize_document,
            "update"        => :deny_array,
            "new"           => :allow
          },
          "delete" => {
            "delete" => :allow,
            "deletes" => :sanitize_bulk,
            "ordered" => :allow
          },
          "bulk" => {
            "q"      => :sanitize_document,
            "u"      => :deny_array,
            "limit"  => :allow,
            "multi"  => :allow,
            "upsert" => :allow
          },
          "aggregation" => :sanitize_document
        }.freeze

        # Format command based on given strategy
        def self.format(strategy, command)
          # Stop processing if command is not a hash
          return {} unless command.is_a?(Hash)

          # Get the strategy and stop if it's not present
          strategies = ALLOWED[strategy.to_s]
          return {} unless strategies

          {}.tap do |hsh|
            command.each do |key, val|
              hsh[key] = apply_strategy(strategies[key], val)
            end
          end
        end

        # Applies strategy on hash values based on keys
        def self.apply_strategy(strategy, val)
          filter_keys = Appsignal.config[:filter_query_parameters]
          should_filter = filter_keys.include?('*')
          case strategy
          when :allow      then val
          when :deny
            if should_filter
              '?'
            else
              Appsignal::Utils::QueryParamsSanitizer.sanitize(val, filter_keys)
            end
          when :deny_array
            if should_filter
              "[?]"
            else
              Appsignal::Utils::QueryParamsSanitizer.sanitize(val, filter_keys)
            end
          when :sanitize_document
            Appsignal::Utils::QueryParamsSanitizer.sanitize(
              val, filter_keys, true
            )
          when :sanitize_bulk
            output = val[0..9].map { |v| format(:bulk, v) }
            output.push("[...]") if val.length > 10
            output
          else "?"
          end
        end
      end
    end
  end
end
