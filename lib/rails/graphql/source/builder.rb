# frozen_string_literal: true

module Rails
  module GraphQL
    class Source
      module Builder

        # Check if the object was already built
        def built?(part = nil)
          defined?(@built) && @built.present? &&
            (part.nil? || @built.include?(part.to_sym))
        end

        # Build all from all descendant sources
        def build_all_sources
          descendants.each(&:build_all)
        end

        # Trigger a safe build of everything
        def build_all
          build_all! unless abstract?
        end

        # Allows building anything that is in hooks
        def respond_to_missing?(method_name, *)
          return super unless method_name.to_s.start_with?('build_') &&
            hook_names.include?(method_name.to_s[6..-1].to_sym)
        end

        # Allow fast creation of values
        def method_missing(method_name, *args, **xargs, &block)
          return super unless method_name.to_s.start_with?('build_')

          type = method_name.to_s[6..-1].singularize.to_sym
          import_skips_for(type, xargs)

          build!(type, *args, **xargs, &block) unless built?(type)
        end

        protected

          # Store the list of built steps
          def built
            @built ||= Set.new
          end

          # Make sure to mark the hook name as built
          def run_hooks(hook_name, *)
            super
          ensure
            built << hook_name
          end

        private

          # Import all options-based settings for skipping field
          def import_skips_for(type, options)
            return if type == :all

            if !(values = options.delete(:except)).nil?
              segmented_skip_fields[type] += GraphQL.enumerate(values).map do |value|
                value.to_s.underscore
              end
            end

            if !(values = options.delete(:only)).nil?
              segmented_only_fields[type] += GraphQL.enumerate(values).map do |value|
                value.to_s.underscore
              end
            end
          end

          # Build all the hooks if it's not built
          def build_all!
            catch(:done) do
              hook_names.to_enum.drop(1).each do |hook|
                send("build_#{hook}")
              end
            end
          end

          # Check if the build process can happen
          def ensure_build!(type)
            raise DefinitionError, (+<<~MSG).squish if hook_names.exclude?(type)
              #{self.name} doesn't know how build #{type}, hook not proper defined.
            MSG

            raise DefinitionError, (+<<~MSG).squish if abstract
              Abstract source #{name} cannot be built.
            MSG

            raise DefinitionError, (+<<~MSG).squish if built?(type)
              The #{type} part is already built.
            MSG
          end

          # Build all the objects associated with this source
          def build!(type)
            ensure_build!(type)

            catch(:skip) { run_hooks(:start) } unless built?(:start)
            catch(:skip) { run_hooks(type, hook_scope_for(type)) }

            built << type.to_sym
          end

          # Get the correct +self_object+ for the hook instance
          def hook_scope_for(type)
            type = type.to_sym
            object =
              if Helpers::WithSchemaFields::TYPE_FIELD_CLASS.key?(type)
                Helpers::WithSchemaFields::ScopedConfig.new(self, type)
              else
                Helpers::AttributeDelegator.new(self, type)
              end

            Source::ScopedConfig.new(self, object, type)
          end

      end
    end
  end
end


