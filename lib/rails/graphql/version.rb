# frozen_string_literal: true

module Rails
  module GraphQL
    # Returns the currently loaded version of the GraphQL as a <tt>Gem::Version</tt>.
    def self.gem_version
      Gem::Version.new VERSION::STRING
    end

    module VERSION
      MAJOR = 0
      MINOR = 3
      TINY  = 6
      PRE   = 'alpha'

      STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
    end
  end
end
