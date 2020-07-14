# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # Helper module to collect the directives from fragments, operations, and
      # fields.
      module Directives
        DATA_PARTS = %i[directives]

        attr_reader :directives

        # Add the +directives+ to the list of data parts
        def data_parts
          defined?(super) ? DATA_PARTS + super : DATA_PARTS
        end

        protected

          def parse_directives!(location = nil)
            list = []
            visitor.collect_directives(*data[:directives]) do |data|
              data[:arguments].transform_values! do |value|
                next value unless value.is_a?(::FFI::Pointer)

                var_name = visitor.node_name(value)
                raise ArgumentError, <<~MSG.squish unless respond_to?(:variables)
                  Unable to use variable "$#{var_name}" out of an operation
                MSG

                variables[var_name]
              end

              list << GraphQL.type_map.fetch!(
                data[:name],
                base_class: :Directive,
                namespaces: schema.namespaces,
              ).new(**data[:arguments])
            end unless data[:directives].empty?

            @directives = GraphQL.directives_to_set(list,
              location: location || kind,
              source: self,
            ).freeze
          end

          def debug_directives!
            response.indented("* Directives(#{directives.size})") do
              directives.each { |x| response << x.inspect }
            end if directives.any?
          end
      end
    end
  end
end
