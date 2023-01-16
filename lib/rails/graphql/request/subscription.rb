# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Subscription
      #
      # A simple object to store information about a generated subscription
      # TODO: Add a callback for the schema allowing it to prepare the context
      # before saving it into a subscription
      class Subscription
        NULL_SCOPE = Object.new.freeze

        attr_reader :sid, :schema, :args, :field, :scope, :context, :broadcastable,
          :origin, :last_updated_at, :operation_id

        alias broadcastable? broadcastable

        def initialize(request, operation)
          entrypoint = operation.selection.each_value.first

          @schema = request.schema.namespace
          @origin = request.origin
          @operation_id = operation.hash
          @args = entrypoint.arguments.to_h
          @field = entrypoint.field
          @context = request.context.to_h
          @broadcastable = operation.broadcastable?
          updated!

          @scope = parse_scope(field.full_scope, request, operation)
          @sid = request.schema.subscription_id_for(self)
        end

        def updated!
          @last_updated_at = Time.current
        end

        def marshal_dump
          raise ::TypeError, +"Request subscriptions must not be used as payload."
        end

        def inspect
          (+<<~INFO).squish << '>'
            #<#{self.class.name}
            #{schema}@#{sid}
            [#{scope.nil? ? scope.inspect : scope.hash}, #{args.hash}]
            #{field.inspect}
          INFO
        end

        protected

          def parse_scope(list, request, operation)
            enum = GraphQL.enumerate(list)
            return NULL_SCOPE if enum.empty?

            ext_self = nil
            enum.map do |item|
              case item
              when Symbol
                context[item]
              when Proc
                next item.call if item.arity == 0

                ext_self ||= SimpleDelegator.new(self).tap do |object|
                  object.define_singleton_method(:request) { request }
                  object.define_singleton_method(:operation) { operation }
                end

                item.call(ext_self)
              else
                item
              end
            end.compact
          end
      end
    end
  end
end
