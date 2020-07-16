# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold an +assigned_to+ object
      module WithAssignment
        # Add extra instance based methods
        def self.extended(other)
          other.delegate(:assigned_to, :assigned_class, to: :class)
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
            if defined?(@base_class) && !klass <= @base_class
              message = @error_block.present? ? @error_block.call(klass) : <<~MSG.squish
                The "#{klass.name}" is not a subclass of #{@base_class.name}.
              MSG

              raise ::ArgumentError, message
            end

            klass
          end
        end

        protected

          # Allows validating the +assigned_class+ before resolving it, making
          # sure that it is a subclass of +base_class+. Use the +block+ to
          # customize the error message
          def validate_assignment(base_class, &block)
            self.assigned_to = base_class
            @error_block = block
          end
      end
    end
  end
end
