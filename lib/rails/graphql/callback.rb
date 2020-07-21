# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = Rails GraphQL Callback
    #
    # An extra powerfull proc that can handle way more situations than the
    # original block caller
    class Callback
      attr_reader :event_name, :block

      def initialize(target, event_name, *args, **xargs, &block)
        raise ::ArgumentError, <<~MSG.squish if block.nil? && !args.first.present?
          Either provide a block or a method name when setting a #{event_name}
          callback on #{target.inspect}.
        MSG

        if block.nil?
          block = args.shift
          valid_format = block.is_a?(Symbol) || block.is_a?(Proc)
          raise ::ArgumentError, <<~MSG.squish unless valid_format
            The given #{block.class.name} class is not a valid callback.
          MSG
        end

        @target = target
        @event_name = event_name

        @pre_args = args
        @pre_xargs = xargs.slice!(*target.event_filters.keys)
        @filters = xargs

        @block = block
      end

      # This does the whole checking and preparation in order to really execute
      # the callback method
      def call
      end

      # This basically allows the class to be passed as +&block+
      def to_proc
        method(:call).to_proc
      end
    end
  end
end
