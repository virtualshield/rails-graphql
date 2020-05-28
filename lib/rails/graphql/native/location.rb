module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
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

        private :[], :[]=
      end
    end
  end
end
