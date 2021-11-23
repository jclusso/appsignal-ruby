# frozen_string_literal: true

module Appsignal
  module Integrations
    module RedisIntegration
      def write(command)
        command_string =
          if Appsignal.config[:filter_redis_arguments]
            if command[0] == :eval
              "#{command[1]}#{" ?" * (command.size - 3)}"
            else
              "#{command[0]}#{" ?" * (command.size - 1)}"
            end
          else
            command.join(' ')[0..999]
          end

        Appsignal.instrument "query.redis", id, command_string do
          super
        end
      end
    end
  end
end
