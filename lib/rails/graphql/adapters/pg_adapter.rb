# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Based on:
    # SELECT t.oid, t.typname, format_type(t.oid, NULL) AS sql_type
    # FROM pg_type t
    # WHERE typtype = 'b'
    #   AND typcategory IN ('B', 'D', 'G', 'I', 'N', 'S', 'T', 'V')
    #   AND typowner = 10;
    type_map.register_alias 'pg:boolean',                     :boolean
    type_map.register_alias 'pg:integer',                     :int
    type_map.register_alias 'pg:date',                        :date

    type_map.register_alias 'pg:char',                        :string
    type_map.register_alias 'pg:bigint',                      :id
    type_map.register_alias 'pg:smallint',                    :int
    type_map.register_alias 'pg:text',                        :string
    type_map.register_alias 'pg:oid',                         :int
    type_map.register_alias 'pg:real',                        :float
    type_map.register_alias 'pg:double precision',            :float
    type_map.register_alias 'pg:money',                       :decimal
    type_map.register_alias 'pg:character',                   :string
    type_map.register_alias 'pg:character varying',           :string
    type_map.register_alias 'pg:timestamp',                   :date_time
    type_map.register_alias 'pg:timestamp without time zone', :date_time
    type_map.register_alias 'pg:timestamp with time zone',    :date_time
    type_map.register_alias 'pg:time without time zone',      :time
    type_map.register_alias 'pg:time with time zone',         :time
    type_map.register_alias 'pg:numeric',                     :decimal

    module PG # :nodoc: all
      module SourceMethods
        protected

          def pg_attributes
            model.columns_hash.each_value do |column|
              type_name = column.sql_type_metadata.sql_type
              type = find_type!('pg:' + type_name.gsub(/(\(|\[).*/, ''), fallback: :string)

              options = { array: type_name.include?('[]') }
              yield column.name, type, options
            end
          end
      end
    end

    Source::ActiveRecordSource.extend(PG::SourceMethods)
  end
end
