# frozen_string_literal: true

module Rails
  module GraphQL
    # Based on:
    # SELECT t.oid, t.typname, format_type(t.oid, NULL) AS sql_type
    # FROM pg_type t
    # WHERE typtype = 'b'
    #   AND typcategory IN ('B', 'D', 'G', 'I', 'N', 'S', 'T', 'U', 'V')
    #   AND typowner = 10;
    type_map.register_alias 'pg:bigint',                      :bigint
    type_map.register_alias 'pg:boolean',                     :boolean
    type_map.register_alias 'pg:text',                        :string
    type_map.register_alias 'pg:date',                        :date
    type_map.register_alias 'pg:integer',                     :int
    type_map.register_alias 'pg:json',                        :json
    type_map.register_alias 'pg:numeric',                     :decimal
    type_map.register_alias 'pg:real',                        :float
    type_map.register_alias 'pg:time without time zone',      :time
    type_map.register_alias 'pg:timestamp',                   :date_time

    type_map.register_alias 'pg:char',                        'pg:text'
    type_map.register_alias 'pg:smallint',                    'pg:integer'
    type_map.register_alias 'pg:oid',                         'pg:integer'
    type_map.register_alias 'pg:double precision',            'pg:real'
    type_map.register_alias 'pg:money',                       'pg:numeric'
    type_map.register_alias 'pg:character',                   'pg:text'
    type_map.register_alias 'pg:character varying',           'pg:text'
    type_map.register_alias 'pg:timestamp without time zone', 'pg:timestamp'
    type_map.register_alias 'pg:timestamp with time zone',    'pg:timestamp'
    type_map.register_alias 'pg:time with time zone',         'pg:time without time zone'
    type_map.register_alias 'pg:jsonb',                       'pg:json'

    module PG
      module SourceMethods
        protected

          def pg_attributes
            model.columns_hash.each_value do |column|
              next yield(column.name, find_type!(:id)) if id_columns.include?(column.name)

              type_name = column.sql_type_metadata.sql_type
              type = find_type!('pg:' + type_name.gsub(/(\(|\[).*/, ''), fallback: :string)

              options = { array: type_name.include?('[]') }
              yield(column.name, type, **options)
            end
          end
      end
    end

    Source::ActiveRecordSource.extend(PG::SourceMethods)
  end
end
