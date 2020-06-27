# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold an +assigned_to+ object
      module WithAssignment
        # Add the attribute that holds the class assigned
        def self.extended(other)
          other.class_attribute(:assigned_to, instance_writer: false)
        end

        # Make sure to always save the assignment as string, so that
        # +assigned_class+ can return the actual object
        def assigned_to=(value)
          @assigned_to = value.is_a?(Module) ? value.name : value
        end

        # Return the actual class object of the assignment
        def assigned_class
          @assigned_class ||= begin
            klass = assigned_to.constantize
            if defined?(@base_klass) && !klass <= @base_klass
              message = @error_block.present? ? @error_block.call(klass) : <<~MSG.squish
                The "#{klass.name}" is not a subclass of #{@base_klass.name}.
              MSG

              raise ::ArgumentError, message
            end

            klass
          end
        end

        alias assigned_klass assigned_class

        protected

          # Allows validating the +assigned_class+ before resolving it, making
          # sure that it is a subclass of +base_klass+. Use the +block+ to
          # customize the error message
          def validate_assignment(base_klass, &block)
            @error_block = block
            @base_klass = base_klass
          end
      end
    end
  end
end
