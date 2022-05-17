# frozen_string_literal: true

module Rails
  module GraphQL
    # Based on:
    # SELECT DISTINCT data_type FROM information_schema.columns;
    # And https://www.mysqltutorial.org/mysql-data-types.aspx
    type_map.register_alias 'mysql:varchar',      :string
    type_map.register_alias 'mysql:bit',          :bool
    type_map.register_alias 'mysql:int',          :int
    type_map.register_alias 'mysql:bigint',       :bigint
    type_map.register_alias 'mysql:json',         :json
    type_map.register_alias 'mysql:date',         :date
    type_map.register_alias 'mysql:timestamp',    :date_time
    type_map.register_alias 'mysql:binary',       :binary
    type_map.register_alias 'mysql:float',        :float
    type_map.register_alias 'mysql:decimal',      :decimal
    type_map.register_alias 'mysql:time',         :time

    type_map.register_alias 'mysql:set',          'mysql:varchar'
    type_map.register_alias 'mysql:text',         'mysql:varchar'
    type_map.register_alias 'mysql:enum',         'mysql:varchar'
    type_map.register_alias 'mysql:char',         'mysql:varchar'
    type_map.register_alias 'mysql:tinytext',     'mysql:text'
    type_map.register_alias 'mysql:mediumtext',   'mysql:text'
    type_map.register_alias 'mysql:longtext',     'mysql:text'
    type_map.register_alias 'mysql:datetime',     'mysql:timestamp'
    type_map.register_alias 'mysql:varbinary',    'mysql:binary'
    type_map.register_alias 'mysql:blob',         'mysql:binary'
    type_map.register_alias 'mysql:tinyblob',     'mysql:blob'
    type_map.register_alias 'mysql:mediumblob',   'mysql:blob'
    type_map.register_alias 'mysql:longblob',     'mysql:blob'
    type_map.register_alias 'mysql:tinyint',      'mysql:int'
    type_map.register_alias 'mysql:smallint',     'mysql:int'
    type_map.register_alias 'mysql:mediumint',    'mysql:int'
    type_map.register_alias 'mysql:double',       'mysql:float'

    module MySQL
      module SourceMethods
        protected

          def mysql_attributes
            model.columns_hash.each_value do |column|
              next yield(column.name, find_type!(:id)) if id_columns.include?(column.name)

              base_type, size = column.sql_type_metadata.sql_type.split(/(\(\d+\))/)
              type_name = base_type.end_with?('int') && size == '(1)' ? 'bit' : base_type

              type = find_type!("mysql:#{type_name}", fallback: :string)

              yield(column.name, type, array: (base_type == 'set'))
            end
          end
      end
    end

    Source::ActiveRecordSource.extend(MySQL::SourceMethods)
  end
end
