# frozen_string_literal: true

module Rails
  module GraphQL
    module Native
      # Helper class to get the line and column information of a node
      class Location < FFI::Struct
        layout(
          beginLine: :uint,
          beginColumn: :uint,
          endLine: :uint,
          endColumn: :uint,
        )

        def begin_line
          self[:beginLine]
        end

        def begin_column
          self[:beginColumn]
        end

        def end_line
          self[:endLine]
        end

        def end_column
          self[:endColumn]
        end

        def to_errors
          [
            { 'line' => begin_line, 'column' => begin_column },
            { 'line' => end_line,   'column' => end_column },
          ]
        end

        private :[], :[]=
      end
    end
  end
end
