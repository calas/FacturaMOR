module RedHillConsulting::Core::ActiveRecord::ConnectionAdapters
  module PostgresqlAdapter
    def self.included(base)
      base.class_eval do
        alias_method_chain :indexes, :redhillonrails_core
      end
    end

    def add_index(table_name, column_name, options = {})
      column_names = Array(column_name)
      index_name   = index_name(table_name, :column => column_names)

      if Hash === options # legacy support, since this param was a string
        index_type = options[:unique] ? "UNIQUE" : ""
        index_name = options[:name] || index_name
      else
        index_type = options
      end

      quoted_column_names = column_names.map { |e| options[:ignore_case] && e !~ /_id$/ ? "lower(#{quote_column_name(e)})" : quote_column_name(e) }

      execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{table_name} (#{quoted_column_names.join(", ")})"
    end

    def indexes_with_redhillonrails_core(table_name, name = nil)
      indexes = indexes_without_redhillonrails_core(table_name, name)
      result = query(<<-SQL, name)
        SELECT c2.relname, i.indisunique, pg_catalog.pg_get_indexdef(i.indexrelid, 0, true)
          FROM pg_catalog.pg_class c, pg_catalog.pg_class c2, pg_catalog.pg_index i
         WHERE c.relname = '#{table_name}'
           AND c.oid = i.indrelid AND i.indexrelid = c2.oid
           AND i.indisprimary = 'f'
           AND i.indexprs IS NOT NULL
         ORDER BY 1
      SQL

      result.each do |row|
        if row[2] =~ /\(lower\((.*)::text\)\)/i
          index = ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, row[0], row[1] == "t", [$1])
          index.ignore_case = true
          indexes << index
        end
      end

      indexes
    end

    def foreign_keys(table_name, name = nil)
      load_foreign_keys(<<-SQL, name)
        SELECT f.conname, pg_get_constraintdef(f.oid), t.relname
          FROM pg_class t, pg_constraint f
         WHERE f.conrelid = t.oid
           AND f.contype = 'f'
           AND t.relname = '#{table_name}'
      SQL
    end

    def reverse_foreign_keys(table_name, name = nil)
      load_foreign_keys(<<-SQL, name)
        SELECT f.conname, pg_get_constraintdef(f.oid), t2.relname
          FROM pg_class t, pg_class t2, pg_constraint f
         WHERE f.confrelid = t.oid
           AND f.conrelid = t2.oid
           AND f.contype = 'f'
           AND t.relname = '#{table_name}'
      SQL
    end

    private

    def load_foreign_keys(sql, name = nil)
      foreign_keys = []

      query(sql, name).each do |row|
          if row[1] =~ /^FOREIGN KEY \((.+?)\) REFERENCES (.+?)\((.+?)\)( ON UPDATE (.+?))?( ON DELETE (.+?))?$/
              name = row[0]
              from_table_name = row[2]
              column_names = $1
              references_table_name = $2
              references_column_names = $3
              on_update = $5
              on_delete = $7
              on_update = on_update.downcase.gsub(' ', '_').to_sym if on_update
              on_delete = on_delete.downcase.gsub(' ', '_').to_sym if on_delete

              foreign_keys << ForeignKey.new(name,
                                             from_table_name, column_names.split(', '),
                                             references_table_name.sub(/^"(.*)"$/, '\1'), references_column_names.split(', '),
                                             on_update, on_delete)
          end
      end

      foreign_keys
    end
  end
end
