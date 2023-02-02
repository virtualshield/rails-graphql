# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Subscription
      #
      # A simple object to store information about a generated subscription
      # TODO: Maybe add a callback for the schema allowing it to prepare the
      # context before saving it into a subscription
      class Subscription
        NULL_SCOPE = Object.new.freeze

        attr_reader :sid, :schema, :args, :field, :scope, :context, :broadcastable,
          :origin, :created_at, :updated_at, :operation_id

        alias broadcastable? broadcastable
        alias id sid

        def initialize(request, operation)
          entrypoint = operation.selection.each_value.first            # Memory Fingerprint

          @schema = request.schema.namespace                           # 1 Symbol
          @origin = request.origin                                     # * HEAVY!
          @operation_id = operation.hash                               # 1 Integer
          @args = entrypoint.arguments.to_h                            # 1 Hash of GQL values
          @field = entrypoint.field                                    # 1 Pointer
          @context = request.context.to_h                              # 1 Hash +/- heavy
          @broadcastable = operation.broadcastable?                    # 1 Boolean
          @created_at = Time.current                                   # 1 Integer
          updated!                                                     # 1 Integer

          @scope = parse_scope(field.full_scope, request, operation)   # 1 Integer after save
          @sid = request.schema.subscription_id_for(self)              # 1 String
        end

        def updated!
          @updated_at = Time.current
        end

        def marshal_dump
          raise ::TypeError, +"Request subscriptions must not be used as payload."
        end

        def inspect
          (+<<~INFO).squish << '>'
            #<#{self.class.name}
            #{schema}@#{sid}
            [#{scope.inspect}, #{args.hash}]
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
