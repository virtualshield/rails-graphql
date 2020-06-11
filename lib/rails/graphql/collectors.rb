# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Collectors # :nodoc:
      extend ActiveSupport::Autoload

      autoload :HashCollector
      autoload :IdentedCollector
      autoload :JsonCollector

    end
  end
end
