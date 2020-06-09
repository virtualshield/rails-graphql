# frozen_string_literal: true

require 'ffi'

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native
      extend FFI::Library

      VERSION = GQLAst::VERSION

      dl_name = "graphqlparser.#{RbConfig::MAKEFILE_CONFIG['DLEXT']}"
      dl_path = Pathname.new(__dir__)

      begin
        ffi_lib(dl_path.join("../../#{dl_name}").to_s)
      rescue LoadError
        ffi_lib(dl_path.join("../../../../ext/#{dl_name}").to_s)
      end

      require_relative 'native/location'
      require_relative 'native/visitor'
      require_relative 'native/pointers'

      attach_function :graphql_parse_string, [:string, :pointer], AstNode

      attach_function :to_json, :graphql_ast_to_json, [AstNode], :string

      attach_function :free_node, :graphql_node_free, [AstNode], :void

      attach_function :node_location, :graphql_node_get_location, [AstNode, Location], :void

      attach_function :visit, :graphql_node_visit, [AstNode, Visitor, :pointer], :void

      def self.parse(content)
        error = Native::ParseError.new
        result = graphql_parse_string(content, error)
        return result if error.empty?
        raise GraphQL::ParseError, error.to_s
      end
    end
  end
end
