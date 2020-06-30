# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      module WithCallbacks
        def self.included(other)
          other.class_attribute(:__callbacks, instance_writer: false, default: {})
        end

        class Callback
          def self.build(filter, type)
            raise ArgumentError, <<-MSG.squish unless filter.is_a?(Symbol) || filter.is_a?(Proc)
              Filter type not supported. Pass a symbol for an instance method, or a lambda, proc or block.
            MSG

            new filter, type
          end

          attr_reader :filter, :type

          def initialize(filter, type)
            @filter = filter
            @type   = type
          end

          def add_to(chain)
            remove_duplicates(chain)
            chain.push(self)
          end

          def remove_duplicates(chain)
            chain.delete_if { |c| duplicates?(c) }
          end

          private

          def duplicates?(other)
            return matches?(other.filter, other.type) if filter.is_a? Symbol
            false
          end

          def matches?(_filter, _type)
            filter == _filter && type == _type
          end
        end

        def resolve_callbacks!
          %w[before resolve after].each { |key| send("run_#{key}_callbacks") }
        end

        def before_resolve(*filter_list, &block)
          resolve_callback :before, filter_list, block
        end

        def after_resolve(*filter_list, &block)
          resolve_callback :after, filter_list, block
        end

        def resolve(&block)
          raise ArgumentError, <<-MSG.squish if @resolved
            Can only have one resolve block.
          MSG

          resolve_callback :resolve, [], block
          @resolved = true
        end

        protected

        # __callbacks = {
        #   before: [#<Callback>, #<Callback>],
        #   resolve: [#<Callback>],
        #   after: [#<Callback>, #<Callback>]
        # }

        def resolve_callback(type, filter_list, block)
          set_callbacks type

          chain = get_callbacks type
          filter_list.unshift(block) if block
          filter_list.each do |filter|
            callback = Callback.build(filter.to_proc, type)
            callback.add_to chain
          end
        end

        def set_callbacks(type)
          __callbacks[type.to_sym] ||= []
        end

        def get_callbacks(type)
          __callbacks[type.to_sym]
        end

        %i[before after].each do |key|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def run_#{key}_callbacks
              return if __callbacks[:#{key}].blank? 
              __callbacks[:#{key}].each do |callback|
                callback.filter.call self
              end
            end
          RUBY
        end
      end
    end
  end
end
