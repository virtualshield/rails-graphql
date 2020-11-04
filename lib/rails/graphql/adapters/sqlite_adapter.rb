# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:

    # Based on:
    # https://github.com/rails/rails/blob/v6.0.0/activerecord/lib/active_record/
    # connection_adapters/sqlite3_adapter.rb#L64
    type_map.register_alias 'sqlite:primary_key', :id
    type_map.register_alias 'sqlite:string',      :string
    type_map.register_alias 'sqlite:text',        :string
    type_map.register_alias 'sqlite:integer',     :int
    type_map.register_alias 'sqlite:float',       :float
    type_map.register_alias 'sqlite:decimal',     :decimal
    type_map.register_alias 'sqlite:datetime',    :date_time
    type_map.register_alias 'sqlite:time',        :time
    type_map.register_alias 'sqlite:date',        :date
    type_map.register_alias 'sqlite:binary',      :binary
    type_map.register_alias 'sqlite:boolean',     :boolean
    # TODO: Add support to JSON type
    # type_map.register_alias 'pg:json',  :json

    module SQLite # :nodoc: all
      module SourceMethods
        protected

          def sqlite_attributes
            model.columns_hash.each_value do |column|
              type_name = column.sql_type_metadata.sql_type
              type = find_type!("sqlite:#{type_name}", fallback: :string)
              yield column.name, type
            end
          end
      end
    end

    Source::ActiveRecordSource.extend(SQLite::SourceMethods)
  end
end
