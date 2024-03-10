# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # Contains the information about a pagination
      class Object::PageInfoObject < Object
        self.assigned_to = 'Rails::GraphQL::Directive::PaginateDirective'

        rename! '_PageInfo'

        desc 'Describe the pagination information for a paginated field.'

        field :id,       'ID'
        field :mode,     '_PaginationMode', null: false
        field :limit,    'Int', null: false
        field :current,  'ID', null: false

        field :field,    'String', full: true, method_name: :field_path
        field :previous, 'ID'
        field :next,     'ID'
        field :count,    'Int'
        field :pages,    'Int'
      end
    end
  end
end
