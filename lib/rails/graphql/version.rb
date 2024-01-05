# frozen_string_literal: true

module Rails
  module GraphQL
    # Returns the currently loaded version of the GraphQL as a <tt>Gem::Version</tt>.
    def self.gem_version
      Gem::Version.new(version)
    end

    def self.version
      VERSION::STRING
    end

    module VERSION
      MAJOR = 1
      MINOR = 0
      TINY  = 1
      PRE   = nil

      STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
    end
  end
end
