# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # The String scalar type represents textual data, represented as UTF-8
      # character sequences.
      #
      # See http://spec.graphql.org/June2018/#sec-String
      class Scalar::StringScalar < Scalar
        self.spec_object = true

        desc <<~DESC
          The String scalar type represents textual data, represented as UTF-8 character
          sequences.
        DESC

        class << self
          def valid_input?(value)
            super || valid_token?(value, :heredoc)
          end

          def as_json(value)
            value = value.to_s unless value.is_a?(String)
            value = value.encode(Encoding::UTF_8) unless value.encoding.eql?(Encoding::UTF_8)
            value
          end

          def deserialize(value)
            if valid_token?(value, :string)
              value[1..-2] # Remove the quotes
            elsif valid_token?(value, :heredoc)
              value[3..-4].strip_heredoc # Remove the quotes and fix indentation
            else
              value
            end
          end
        end
      end
    end
  end
end
