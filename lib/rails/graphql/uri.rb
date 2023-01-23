# frozen_string_literal: true

module URI
  # URI::GLQ encodes objects from a GraphQL server as an URI.
  # It has the components:
  # All components except version and params are required.
  #
  # The URI format looks like "glq://namespace/class_name/gql_name".
  # There are some cases where the name will be further scoped like fields in a
  # query.
  #
  # Params use the power of +Rack::Utils.parse_nested_query+ to make sure that
  # nested elements can be correctly parsed. In the presence of params, even
  # with just a simple +?+ with no actual params, it indicates an instance of
  # the object.
  #
  # TODO: Implement version
  class GQL < Generic
    COMPONENT = %i[scheme namespace class_name scope name params].freeze

    attr_reader :class_name, :scope, :name, :params

    class << self
      # Create a new URI::GQL by parsing a gid string with argument check.
      #
      #   URI::GQL.parse 'glq://base/Directive/deprecated'
      #
      # This differs from URI() and URI.parse which do not check arguments.
      #
      #   URI('gql://bcx')             # => URI::GQL instance
      #   URI.parse('gql://bcx')       # => URI::GQL instance
      #   URI::GQL.parse('gql://bcx/') # => raises URI::InvalidComponentError
      def parse(uri)
        generic_components = URI.split(uri) << nil << true # nil parser, true arg_check
        new(*generic_components)
      end

      # Shorthand to build a URI::GQL from an object and optional scope
      # and params.
      #
      #   URI::GQL.create(GraphQL::Directive::DeprecatedDirective)
      def create(object, scope = nil, params = nil)
        namespace = Rails::GraphQL.enumerate(object.namespaces).first || :base
        klass = object.gid_base_class

        xargs = { namespace: namespace, scope: scope, params: params }
        xargs[:name] = object.gql_name unless klass == Rails::GraphQL::Schema
        xargs[:class_name] =
          case
          when klass <= Rails::GraphQL::Schema then 'Schema'
          when klass.superclass == Rails::GraphQL::Type then 'Type'
          else
            klass_name = klass.is_a?(Module) ? klass.name : klass.class.name
            klass_name.split('GraphQL::').last
          end

        build(xargs)
      end

      # Create a new URI::GQL from components with argument check.
      #
      # Using a hash:
      #
      #   URI::GQL.build(app: 'bcx', model_name: 'Person', model_id: '1', params: { key: 'value' })
      #
      # Using an array, the arguments must be in order [app, model_name, model_id, params]:
      #
      #   URI::GQL.build(['bcx', 'Person', '1', key: 'value'])
      def build(args)
        parts = Util.make_components_hash(self, args)
        parts[:host] = parts[:namespace].to_s.tr('_', '-')
        parts[:path] = [parts[:class_name], parts[:scope], parts[:name]].compact.join('/')
        parts[:path].prepend('/')

        parts[:query] = parts[:params].to_param unless parts[:params].nil?

        super parts
      end
    end

    # Make sure to convert dashes into underscore
    def namespace
      host.tr('-', '_')
    end

    # Check if the object should be instantiated
    def instantiate?
      !query.nil?
    end

    # Implement #to_s to avoid no implicit conversion of nil into string when path is nil
    def to_s
      +"gql://#{host}#{path}#{'?' + query if query}"
    end

    protected

      def set_path(path)
        set_components(path) unless defined?(@class_name) && @name
        super
      end

      def query=(query)
        set_params parse_query_params(query)
        super
      end

      def set_params(params)
        @params = params
      end

    private

      def check_host(host)
        validate_component(host)
        super
      end

      def check_path(path)
        validate_component(path)
        set_components(path, true)
      end

      def check_scheme(scheme)
        return super if scheme == 'gql'
        raise URI::BadURIError, +"Not a gql:// URI scheme: #{inspect}"
      end

      def set_components(path, validate = false)
        parts = path.split('/').slice(1, 3)
        class_name = parts.shift
        name = parts.pop

        validate_component(class_name) && validate_object_name(name, class_name) if validate

        @class_name = class_name
        @scope = parts.shift
        @name = name
      end

      def parse_query_params(query)
        return if query.nil?
        return {} if query.empty?
        Rack::Utils.parse_nested_query(query)
      end

      def validate_component(component)
        raise URI::InvalidComponentError, (+<<~MSG).squish if component.blank?
          Expected a URI like gql://base/Directive/deprecated: #{inspect}.
        MSG
      end

      def validate_object_name(name, class_name)
        raise URI::InvalidComponentError, (+<<~MSG).squish if name.blank?
          Unable to create a GraphQL ID for #{class_name} without an object name.
        MSG
      end

  end

  if respond_to?(:register_scheme)
    register_scheme('GQL', GQL)
  else
    @@schemes['GQL'] = GQL
  end
end
