# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      # Helper module that allows other objects to hold an +assigned_to+ object
      module WithOwner
        def self.included(other)
          other.class_attribute(:owner, instance_writer: false)
        end

        private

          def respond_to_missing?(*args) # :nodoc:
            owner_respond_to?(*args) || super
          end

          def method_missing(method_name, *args, **xargs, &block) # :nodoc:
            return super unless owner_respond_to?(method_name)
            event.on_instance(owner) do |obj|
              obj.public_send(method_name, *args, **xargs, &block)
            end
          end

          # Since owners are classes, this checks for the instance methods of
          # it, since this is a instance method
          def owner_respond_to?(method_name, include_private = false)
            (include_private ? %i[public protected private] : %i[public]).any? do |type|
              owner.send("#{type}_instance_methods").include?(method_name)
            end unless owner.nil?
          end
      end
    end
  end
end
