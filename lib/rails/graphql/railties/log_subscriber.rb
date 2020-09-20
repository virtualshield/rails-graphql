# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Log Subscriber
    #
    # This is the log tracker that workds the same way as ActiveRecord when it
    # has to report on logs that a query was performed.
    class LogSubscriber < ::ActiveSupport::LogSubscriber # :nodoc: all
      class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

      def self.runtime
        RuntimeRegistry.gql_runtime ||= 0
      end

      def self.runtime=(value)
        RuntimeRegistry.gql_runtime = value
      end

      def request(event)
        self.class.runtime += event.duration
        return unless logger.debug?

        payload = event.payload

        name = ['GraphQL', payload[:name].presence]
        name.unshift('CACHE') if payload[:cached]
        name = "#{name.compact.join(' ')} (#{event.duration.round(1)}ms)"

        document = payload[:document].squish
        variables = payload[:variables].blank? ? nil : begin
          "  (#{JSON.pretty_generate(payload[:variables]).squish})"
        end

        debug "  #{color(name, MAGENTA, true)}  #{document}#{variables}"
      end

      private

        def logger
          GraphQL.config.logger
        end

        def debug(*)
          return unless super

          log_query_source if GraphQL.config.verbose_logs
        end

        def log_query_source
          source = extract_query_source_location(caller)
          logger.debug("  ↳ #{source}") if source
        end

        def extract_query_source_location(locations)
          backtrace_cleaner.clean(locations.lazy).first
        end
    end
  end

  GraphQL::LogSubscriber.attach_to :graphql
end
