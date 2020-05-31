# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      extend ActiveSupport::Autoload

      autoload :InheritedCollection
      autoload :LeafFromAr

      autoload :WithArguments
      autoload :WithDirectives
      autoload :WithFields

    end
  end
end
