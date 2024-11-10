# frozen_string_literal: true

require "active_support/parameter_filter"

module Rails
  module GraphQL
    # = GraphQL Log Subscriber
    #
    # This is the log tracker that works the same way as ActiveRecord when it
    # has to report on logs that a query was performed
    class LogSubscriber < ::ActiveSupport::LogSubscriber
      class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

      REMOVE_COMMENTS = /#(?=(?:[^"]*"[^"]*")*[^"]*$).*/

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
        cached = '[CACHE]' if payload[:cached]
        doc = payload[:document]&.gsub(REMOVE_COMMENTS, '')&.squish

        desc = +"#{header(event, cached)}  #{doc}"
        desc << debug_variables(payload[:variables]) unless payload[:variables].blank?

        debug(desc)
      end

      def compile(event)
        return unless logger.debug?

        payload = event.payload
        doc = payload[:document].gsub(REMOVE_COMMENTS, '').squish

        helper = ActiveSupport::NumberHelper::NumberToHumanSizeConverter
        total = helper.convert(payload[:total], EMPTY_HASH)

        debug(+"#{header(event, 'Compile')} #{total}  #{doc}")
      end

      def validate(event)
        return unless logger.debug?

        payload = event.payload
        doc = payload[:document].gsub(REMOVE_COMMENTS, '').squish
        valid = payload[:result] ? color('YES', GREEN) : color('NO', RED)

        debug(+"#{header(event, 'Valid?')} #{valid}  #{doc}")
      end

      def subscription(event)
        return unless logger.info?

        item, type, provider = event.payload.values_at(:item, :type, :provider)
        provider = provider.class.name.sub(/\ARails::GraphQL::Subscription::/, '')
        duration = event.duration.round(1)

        desc = +"#{header(event, provider)} Subscription #{type}"

        unless item.nil?
          hex = { added: GREEN, removed: RED, updated: BLUE }[type]

          if type == :updated
            desc << +": #{color(item.sid, hex)}"
          else
            desc << +": [#{color(item.sid, hex)}] #{item.schema}.#{item.field.gql_name}"
            desc << +" [#{(item.scope === null_subscription_scope ? nil : item.scope).inspect}"
            desc << +", #{item.args.as_json.inspect}]"
          end
        end

        info(desc)
      end

      private

        def logger
          GraphQL.logger
        end

        def debug(*)
          return unless super

          log_query_source if GraphQL.config.verbose_logs
        end

        def header(event, suffix = '')
          duration = event.duration.round(1)
          parts = ['  GraphQL', suffix.presence, event.payload[:name]]
          parts << "(#{duration}ms)" unless duration.zero?

          style = AR710 ? { bold: true } : true
          color(parts.compact.join(' '), MAGENTA, style)
        end

        def debug_variables(vars)
          vars = JSON.pretty_generate(parameter_filter.filter(vars))
          +'  ' << '(' << vars.squish << ')'
        end

        def log_query_source
          source = extract_query_source_location(caller)
          logger.debug(+"  ↳ #{source}") if source
        end

        def extract_query_source_location(locations)
          backtrace_cleaner.clean(locations.lazy).first
        end

        def parameter_filter
          ActiveSupport::ParameterFilter.new(GraphQL.config.filter_parameters)
        end

        def null_subscription_scope
          Request::Subscription::NULL_SCOPE
        end
    end
  end

  GraphQL::LogSubscriber.attach_to :graphql
end
