# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      extend ActiveSupport::Autoload

      autoload :InheritedCollection
      autoload :LeafFromAr
      autoload :Registerable

      autoload :WithArguments
      autoload :WithAssignment
      autoload :WithCallbacks
      autoload :WithDirectives
      autoload :WithFields
      autoload :WithNamespace
      autoload :WithSchemaFields
    end
  end
end
