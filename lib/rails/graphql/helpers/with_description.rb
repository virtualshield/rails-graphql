# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      module WithDescription

        # A getter or setter in the same function
        def desc(value = nil)
          value.nil? ? description : (self.description = value)
        end

        # Define and format description
        def description=(value)
          if !value.nil?
            @description = value.to_s.presence&.strip_heredoc&.chomp
          elsif defined?(@description)
            @description = nil
          end
        end

        # Return a description, by defined value or I18n
        def description(namespace = nil, kind = nil)
          return @description if description?
          return unless GraphQL.config.enable_i18n_descriptions

          i18n_description(namespace, kind)
        end

        # Checks if a description was provided
        def description?
          defined?(@description) && !!@description
        end

        protected

          # Return a description from I18n
          def i18n_description(namespace = nil, kind = nil)
            return if (parent = try(:owner)).try(:spec_object?) &&
              parent.kind != :schema

            values = {
              kind: kind || try(:kind),
              parent: i18n_parent_value(parent),
              namespace: GraphQL.enumerate(namespace || try(:namespaces)).first,
              name: is_a?(Module) ? to_sym : name,
            }

            options = GraphQL.config.i18n_scopes.dup
            while option = options.shift
              key = format(option, values)
              next if key.include?('..')

              result = catch(:exception) { ::I18n.translate(key, throw: true) }
              return result if result.is_a?(String)
            end
          end

          # Properly figure out the parent value for the interpolation
          def i18n_parent_value(parent)
            if parent.respond_to?(:i18n_scope)
              parent.i18n_scope(self)
            elsif parent.is_a?(Helpers::WithSchemaFields) && respond_to?(:schema_type)
              schema_type
            else
              parent.try(:to_sym)
            end
          end

      end
    end
  end
end
