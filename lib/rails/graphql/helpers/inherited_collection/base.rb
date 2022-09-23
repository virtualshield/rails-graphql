module Rails
  module GraphQL
    module Helpers
      # The base class for inherited collections. It helps softly dealing with
      # values defined in multiple class instance variables and look up the tree
      # to make it possible to iterate over combined result
      class InheritedCollection::Base
        include Enumerable

        # Just a little helper to initialize the iterator form a given +source+
        def self.handle(source, ivar, type)
          klass = (type == :array || type == :set) ? :Array : :Hash
          InheritedCollection.const_get(klass).new(source, ivar, type)
        end

        # If the object was instantiated, then it is not empty nor blank
        alias empty? blank?

        def initialize(source, ivar, type)
          @source = source
          @ivar = ivar
          @type = type
        end

        # Overrides the lazy enumerator because each instance variable defined
        # and found by the +each_definition+ will be iterated over lazily
        def lazy
          Enumerator::Lazy.new(each_definition) { |y, d| d.each(&y) }
        end

        protected

          def each_definition
            Enumerator.new do |yielder|
              current = @source
              until current === Object
                yielder << current.instance_variable_get(@ivar) \
                  if current.instance_variable_defined?(@ivar)
                current = current.superclass
              end
            end
          end
      end
    end
  end
end
