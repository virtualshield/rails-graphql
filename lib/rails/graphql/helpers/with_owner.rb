# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper focus on event execution when objects have a owner property,
      # pratically allowing resolvers and similar to be called in the owner
      module WithOwner
        def self.included(other)
          other.extend(WithOwner::ClassMethods)
          other.class_attribute(:owner, instance_writer: false)
        end

        module ClassMethods
          def method_defined?(method_name)
            super || owner&.method_defined?(method_name)
          end
        end

        private

          def respond_to_missing?(*args)
            owner_respond_to?(*args) || super
          end

          def method_missing(method_name, *args, **xargs, &block)
            return super unless owner_respond_to?(method_name)
            event.on_instance(owner) do |obj|
              obj.public_send(method_name, *args, **xargs, &block)
            end
          end

          # Since owners are classes, this checks for the instance methods of
          # it, since this is a instance method
          def owner_respond_to?(method_name, with_private = false)
            return true if !owner.is_a?(Class) && owner.respond_to?(method_name, with_private)
            (with_private ? %i[public protected private] : %i[public]).any? do |type|
              owner.send("#{type}_instance_methods").include?(method_name)
            end unless owner.nil?
          end
      end
    end
  end
end
