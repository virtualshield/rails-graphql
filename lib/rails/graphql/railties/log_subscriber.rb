# frozen_string_literal: true

require "active_support/parameter_filter"

module Rails
  module GraphQL
    # = GraphQL Log Subscriber
    #
    # This is the log tracker that workds the same way as ActiveRecord when it
    # has to report on logs that a query was performed.
    class LogSubscriber < ::ActiveSupport::LogSubscriber
      class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

      REMOVE_COMMENTS = /#(?=(?:[^"]*"[^"]*")*[^"]*$).*/m

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

        document = payload[:document].gsub(REMOVE_COMMENTS, '').squish
        variables = payload[:variables].blank? ? nil : begin
          values = parameter_filter.filter(payload[:variables])
          "  (#{JSON.pretty_generate(values).squish})"
        end

        debug "  #{color(name, MAGENTA, true)}  #{document}#{variables}"
      end

      private

        def logger
          GraphQL.logger
        end

        def parameter_filter
          ActiveSupport::ParameterFilter.new(GraphQL.config.filter_parameters)
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
