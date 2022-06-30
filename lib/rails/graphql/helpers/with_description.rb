# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      module WithDescription

        # Define and format description
        def description=(value)
          @description = value.to_s.presence&.strip_heredoc&.chomp
        end

        # Return the description of the argument
        def description(namespace = nil, kind = nil)
          return @description if description? || !GraphQL.config.enable_i18n_descriptions

          kind ||= try(:kind)
          parent = try(:owner)&.to_sym
          namespace ||= try(:namespaces)&.first
          use_name = is_a?(Module) ? to_sym : name

          values = { namespace: namespace, kind: kind, parent: parent, name: use_name }
          keys = GraphQL.config.i18n_scopes.map do |key|
            (key % values).to_sym
          end
          ::I18n.translate!(keys.shift, default: keys)
        rescue I18n::MissingTranslationData
          nil
        end

        # Checks if a description was provided
        def description?
          defined?(@description) && !!@description
        end

      end
    end
  end
end
