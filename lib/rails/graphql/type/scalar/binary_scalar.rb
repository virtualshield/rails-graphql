# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Binary basically allows binary data to be shared using Base64 strings,
      # ensuring the UTF-8 encoding and performing the necessary conversion.
      #
      # It also rely on ActiveModel so it can easily share the same Data object.
      class Scalar::BinaryScalar < Scalar
        aliases :file

        desc <<~DESC
          The Binary scalar type represents a Base64 string.
          Normally used to share files and uploads.
        DESC

        class << self
          def as_json(value)
            Base64.encode64(value.to_s).chomp
          end

          def deserialize(value)
            ActiveModel::Type::Binary::Data.new(Base64.decode64(value))
          end
        end
      end
    end
  end
end
