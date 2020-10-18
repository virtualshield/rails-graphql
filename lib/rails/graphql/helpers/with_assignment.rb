# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold an +assigned_to+ object
      module WithAssignment
        # Add extra instance based methods
        def self.extended(other)
          other.delegate :assigned?, :assigned_to, :safe_assigned_class,
            :assigned_class, to: :class
        end

        # Check if the class is assgined
        def assigned?
          assigned_to.present?
        end

        # Check if the given +value+ is a valid input for the assigned class
        def valid_assignment?(value)
          assigned? && (klass = safe_assigned_class).present? &&
            ((value.is_a?(Module) && value <= klass) || value.is_a?(klass))
        end

        # Check its own class or pass it to the superclass
        def assigned_to
          @assigned_to.presence || superclass.try(:assigned_to)
        end

        # Make sure to always save the assignment as string, so that
        # +assigned_class+ can return the actual object
        def assigned_to=(value)
          if value.is_a?(Module)
            @assigned_class = value
            @assigned_to = value.name
          else
            @assigned_to = value
          end
        end

        # Return the actual class object of the assignment
        def assigned_class
          @assigned_class ||= begin
            klass = assigned_to.constantize
            validate_assignment!(klass)
            klass
          end
        end

        # Get the assigned class, but if an known exception happens, just ignore
        def safe_assigned_class
          assigned_class
        rescue ::ArgumentError, ::NameError
          # Ignores the possible errors here related
        end

        # After a successfully registration, add the assigned class to the
        # type map as a great alias to find the object
        def register!
          return if abstract?
          return super unless assigned?

          super.tap do
            klass = safe_assigned_class
            GraphQL.type_map.register_alias(klass, &method(:itself)) if klass
          end
        end

        protected

          # Allows validating the +assigned_class+ before resolving it, making
          # sure that it is a subclass of +base_class+. Use the +block+ to
          # customize the error message
          def validate_assignment(base_class, &block)
            @base_class = base_class
            @error_block = block unless block.nil?
            self.assigned_to = base_class
          end

          # Check if the given +klass+ is valid, but just when +@base_class+
          # is defined
          def validate_assignment!(klass)
            return if (base_class = base_assignment_class).nil? || klass <= base_class

            klass = self
            block = until klass === Class
              if klass.instance_variable_defined?(:@error_block)
                break klass.instance_variable_get(:@error_block)
              else
                klass = klass.superclass
              end
            end

            message = !block.nil? ? block.call(klass) : <<~MSG.squish
              The "#{klass.name}" is not a subclass of #{base_class.name}.
            MSG

            raise ::ArgumentError, message
          end

          # Find a base class using the inheritance
          def base_assignment_class
            if defined?(@base_class)
              @base_class = @base_class.constantize if @base_class.is_a?(String)
              @base_class
            elsif superclass.respond_to?(:base_assignment_class, true)
              superclass.send(:base_assignment_class)
            end
          end
      end
    end
  end
end
