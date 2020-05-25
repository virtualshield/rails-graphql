# frozen_string_literal: true

require 'ffi'
require 'graphqlparser' unless Object.const_defined?('GQLAst')

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native
      extend FFI::Library

      VERSION = GQLAst::VERSION

      dl_ext = (RbConfig::CONFIG['host_os'] =~ /darwin/ ? 'bundle' : 'so')
      begin
        ffi_lib File.expand_path("graphqlparser.#{dl_ext}", "#{__dir__}/../")
      rescue LoadError # Some non-rvm environments don't copy a shared object over to lib/sassc
        ffi_lib File.expand_path("graphqlparser.#{dl_ext}", "#{__dir__}/../../../ext")
      end

      typedef :pointer, :unique_ptr
      require_relative 'native/ast'

      attach_function :parse, :graphqlparser_parse, [:string], :pointer
      attach_function :get_location, :graphql_node_get_location, [:pointer, GraphQLAstLocation], :void
    end
  end
end
