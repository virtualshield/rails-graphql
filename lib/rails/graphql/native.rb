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
      require_relative 'native/functions'

      attach_function :graphql_parse_string, [:pointer, :pointer], :pointer

      attach_function :to_json, :graphql_ast_to_json, [:pointer], :string

      attach_function :free_node, :graphql_node_free, [:pointer], :void

      attach_function :graphql_node_get_location, [:pointer, Location], :void

      attach_function :visit, :graphql_node_visit, [:pointer, Visitor, :pointer], :void

      # Parse the given GraphQL +content+ string returning the node pointer.
      # The +dup+ here is important to be able to free the memory of the nodes
      # partially. It will raise an exception if +content+ is invalid.
      def self.parse(content)
        error = Native::ParseError.new
        content = FFI::MemoryPointer.from_string(content)
        result = graphql_parse_string(content, error)
        return result if error.empty?
        raise GraphQL::ParseError, error.to_s
      end

      # Return a {+Location+}[rdoc-ref:Rails::GraphQL::Native::Location] class
      # with the location information of the given +node+.
      def self.get_location(node)
        Native::Location.new.tap do |result|
          graphql_node_get_location(node, result)
        end
      end
    end
  end
end
