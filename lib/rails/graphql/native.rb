# frozen_string_literal: true

require 'ffi'

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native
      extend FFI::Library

      VERSION = GQLAst::VERSION

      dl_ext = FFI::Platform.mac? ? 'bundle' : 'so'
      dl_name = "graphqlparser.#{dl_ext}"
      dl_path = Pathname.new(__dir__)

      begin
        ffi_lib(dl_path.join("../../#{dl_name}").to_s)
      rescue LoadError
        ffi_lib(dl_path.join("../../../../ext/#{dl_name}").to_s)
      end

      require_relative 'native/location'

      attach_function :parse, :graphql_parse_string, [:string, :pointer], :pointer

      attach_function :to_json, :graphql_ast_to_json, [:pointer], :string

      attach_function :free_node, :graphql_node_free, [:pointer], :void

      attach_function :free_error, :graphql_error_free, [:pointer], :void

      attach_function :node_location, :graphql_node_get_location, [:pointer, Location], :void

    end
  end
end
