# frozen_string_literal: true

module Appsignal
  module Utils
    # @api private
    class QueryParamsSanitizer
      REPLACEMENT_KEY = "?".freeze

      module ClassMethods

        def sanitize(params, filter_keys, only_top_level = false)
          case params
          when Hash
            sanitize_hash(params, filter_keys, only_top_level)
          when Array
            sanitize_array(params, filter_keys, only_top_level)
          else
            filter_keys.include?('*') ? REPLACEMENT_KEY : params
          end
        end

        private

        def sanitize_hash(hash, filter_keys, only_top_level)
          {}.tap do |h|
            hash.each do |key, value|
              h[key] =
                if only_top_level && should_filter?(key, filter_keys)
                  REPLACEMENT_KEY
                else
                  sanitize(value, filter_keys, only_top_level)
                end
            end
          end
        end

        def sanitize_array(array, filter_keys, only_top_level)
          if only_top_level && filter_keys.include?('*')
            sanitize(array[0], filter_keys, only_top_level)
          else
            output = array[0..9].map do |value|
              sanitize(value, filter_keys, only_top_level)
            end
            output.push('[...]') if array.length > 10
            output
          end
        end

        def should_filter?(key, filter_keys)
          filter_keys.include?('*') || filter_keys.include?(key)
        end

      end

      extend ClassMethods
    end
  end
end
