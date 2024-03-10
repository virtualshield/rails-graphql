# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQl Strategy Validate Limits
      #
      # This strategy is added to any running strategy ensure that the
      # configured limits are enforced. There are three different limits that
      # can be enforced:
      #   - Max depth of any operation
      #   - Max complexity of the request as a whole
      #   - Max repetition of array fields
      module Strategy::ValidateLimits
        TRACK_DEPTH_KINDS = %i[object operation spread].to_set.freeze

        # Add to tracking if the component has a complexity limit
        def track_complexity_for(object)
          # limit = (object.of_type?(:field) && object.properties&.max_complexity) ||
          #   (object.of_type?(:operation) && request.limits&.operation_max_complexity)

          # limit && complexity_tracking[object] = limit
        end

        # Most of the validations happens when elements of the request are
        # stacked. Important limiting information is collected at that time.
        def stacked(object, &block)
          super
          # super(object) do
          #   case @stage
          #   when :organize
          #     validate_depth!(object, &block)
          #   when :resolve
          #     validate_repetition!(object, &block)
          #   end
          # end
        end

        # Ensure to validate the complexity after all data has been collected
        def collect_data(*)
          # super.tap { validate_complexity! }
        end

        protected

          # Stores the trackings of depth limit
          def depth_tracking
            @depth_tracking ||= {}
          end

          # Stores the stack of calculated complexity
          def complexity_tracking
            @complexity_tracking ||= {}
          end

          # Check if repetition is being tracked
          def repetition_tracking
            @repetition_tracking ||= {}
          end

          # Check if max depth is being violated and enforce the limit
          def validate_depth!(object, &block)
            type = object.try(:leaf_type?) ? :object : object.kind
            return yield unless TRACK_DEPTH_KINDS.include?(type)

            # Check if a new limit needs to be tracked
            limit = (type == :operation && request.limits&.max_depth) ||
              (type == :object && object.properties&.try(:max_depth))
            depth_tracking[object] = limit + 1 if limit.present?
            return yield if @depth_tracking&.any?

            # Now we check if there is any limit to be enforced
            depth_tracking.each.with_index do |(component, limit), idx|
              next depth_tracking[component] -= 1 if limit > 0

              # Add the error and invalidate the component
              report_limit!(:depth, 'Reached maximum depth', source: component)
              component.invalidate!

              # Remove all the keys to the right cleaning any still open tracking
              depth_tracking.except!(*depth_tracking.keys[idx..-1])

              # Go back to the when the tracking started
              throw(component)
            end

            # Call the stack with proper tracking
            begin
              limit.present? ? catch(object, &block) : block.call
            ensure
              depth_tracking.delete(object) if limit.present?
              depth_tracking.transform_values!(&:succ)
            end
          end

          # Check if max repetition is being violated and enforce the limit
          def validate_repetition!(object, &block)
            if Numeric == object && current_max_repetition.try(:>=, object)
              report_limit!(:repetition, 'Reached maximum repetition')
              throw(request.stack.last)
            elsif object.try(:array?)
              limit = object.properties&.try(:max_repetition)
              limit ||= request.limits&.max_repetition

              catch(object) do
                repetition_tracking[object] = limit
                return block.call
              ensure
                repetition_tracking.delete(object)
              end if limit.present?
            end

            block.call
          end

          # Check if any complexity limit is being violated and enforce the
          # limit
          def validate_complexity!
            total_limit = request.limits&.max_complexity
            return unless total_limit || @complexity_tracking&.any?

            # Stores the calculated complexity of each component here
            values = {}

            # Go over the list backwards, because violations may change the
            # upper level complexities
            @complexity_tracking&.reverse_each do |component, limit|
              next if total_complexity_of(component, cache: values) <= limit

              # Add the error and invalidate the component
              report_limit!(:complexity, 'Reached maximum complexity', source: component)
              component.invalidate!

              # Zero the complexity, since component won't be used anymore
              values[component] = 0
            end

            # Check if the total complexity doesn't need to be calculated
            return if total_limit.blank?

            total = total_complexity_of(*request.operations.values, cache: values)
            total_max_complexity_reached! unless total <= total_limit
          end

        private

          # Get the max repetition of the current field being iterated
          def current_max_repetition
            @repetition_tracking.try(:[], request.stack.last)
          end

          # Report that a limit has been reached
          def report_limit!(type, message, source: request.stack.last)
            source.report_exception(LimitError.new(message), type: type)
          end

          # Calculate the total complexity of the given items
          def total_complexity_of(*items, cache:)
            items.sum do |component|
              next cache[component] if cache.key?(component)
              next cache[component] = 0 if component.unresolvable?

              # Check if the component is based on sub components
              if (sub_items = component.selection).present?
                # Start the total from fragment if possible
                fragment = component.try(:fragment)
                total = cache[fragment] if fragment
                total ||= total_complexity_of(*sub_items.values, cache: cache)

                # Saves the total of both fragment and component
                cache[fragment] = total if fragment
                next cache[component] = total * size_of(component)
              end

              # Calculate the complexity of the field
              result = component.properties&.complexity
              result = complexity_by_event(component, result)
              result = Numeric === result ? result : 1
              cache[component] = result * size_of(component)
            end
          end

          # Use an event to trigger the block that calculates the complexity
          # of the given component
          def complexity_by_event(component, block)
            return unless block.respond_to?(:call)
            Event.trigger(:complexity, component, self, &block)
          end

          # This is an ultimatum, if not properly rescued, and error will be
          # added and the whole request will be terminated
          def total_max_complexity_reached!
            error = LimitError.new('Reached maximum complexity')
            unchecked = request.rescue_with_handler(error, source: request, type: :complexity)
            return if unchecked == false

            # Add the error message and then trigger a static response
            extra = { exception: error.class.name, stage: @stage, type: :complexity }
            request.report_error(error.message, **extra)
            request.terminate!
          end
      end
    end
  end
end
