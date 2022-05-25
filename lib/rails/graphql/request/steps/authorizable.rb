# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # Helper methods for the authorize step of a request
      module Authorizable
        # Event used to perform an authorization step
        class Event < GraphQL::Event
          # Similar to trigger for object, but with an extra extension for
          # instance methods defined on the given object
          def authorize_using(object, send_args, events = nil)
            cache = data[:request].cache(:authorize)[object] ||= []
            return false if cache.present? && cache.none?
            args, xargs = send_args

            # Authorize through instance method
            using_object = cache[0] ||= authorize_on_object(object)
            set_on(using_object) do |instance|
              instance.public_send(:authorize!, *args, **xargs)
            end if using_object

            # Authorize through events
            using_events = cache[1] ||= (events || object.all_events[:authorize]).presence
            using_events&.each { |block| block.call(self, *args, **xargs) }

            # Does any authorize process ran
            cache.any?
          end

          # Simply unauthorize the operation
          def unauthorized!(*, message: nil, **)
            raise UnauthorizedFieldError, message || (+<<~MSG).squish
              Unauthorized access to "#{field.gql_name}" field.
            MSG
          end

          # Simply authorize the operation
          def authorized!(*)
            throw :authorized
          end

          private

            # Check if it should run call an +authorize!+ method on the given
            # +object+. Classes are turn into instance through strategy
            def authorize_on_object(object)
              as_class = object.is_a?(Class)
              checker = as_class ? :method_defined? : :respond_to?

              return false unless object.public_send(checker, :authorize!)
              as_class ? data[:request].strategy.instance_for(object) : object
            end
        end

        # Check if the field is correctly authorized to be executed
        # TODO: Implement reverse order of authorization
        def check_authorization!
          return unless field.authorizable?
          *args, block = field.authorizer

          catch(:authorized) do
            event = authorization_event
            schema_events = request.all_events[:authorize]
            executed = event.authorize_using(schema, args, schema_events)

            element = field
            while element && element != schema
              executed = event.authorize_using(element, args) || executed
              element = element.try(:owner)
            end

            if block.present?
              block.call(event, *args[0], **args[1])
              executed = true
            end

            event.unauthorized!(message: (+<<~MSG).squish) unless executed
              Authorization required but unable to be executed
            MSG
          end
        rescue UnauthorizedFieldError => error
          request.rescue_with_handler(error)
          request.exception_to_error(error, self)
          invalidate!
        end

        private

          # Build and store the authorization event
          def authorization_event
            Event.new(:authorize, self,
              context: request.context,
              request: request,
              schema: schema,
              field: field,
              memo: memo,
            )
          end
      end
    end
  end
end
