# frozen_string_literal: true

module Rails
  module GraphQL
    # All the possible collectors that uses the reverse visit approach
    module Collectors
      extend ActiveSupport::Autoload

      autoload :HashCollector
      autoload :IdentedCollector
      autoload :JsonCollector
    end
  end
end
