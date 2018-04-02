require 'sequel'

module Sequel
  class Annotate
    # Append/replace the schema comment for all of the given files.
    # Attempts to guess the model for each file using a regexp match of
    # the file's content, if this doesn't work, you'll need to create
    # an instance manually and pass in the model and path. Example:
    # 
    #   Sequel::Annotate.annotate(Dir['models/*.rb'])
    def self.annotate(paths, options = {})
      Sequel.extension :inflector
      paths.each do |path|
        if match = File.read(path).match(/class (\S+)\s*<\s*Sequel::Model/)
          new(match[1].constantize).annotate(path, options)
        end
      end
    end

    # The model to annotate
    attr_reader :model

    # Store the model to annotate
    def initialize(model)
      @model = model
    end

    # Append the schema comment (or replace it if one already exists) to
    # the file at the given path.
    def annotate(path, options = {})
      orig = current = File.read(path).rstrip

      if options[:position] == :before
        current = current.gsub(/\A#\sTable[^\n\r]+\r?\n(?:#[^\n\r]*\r?\n)*/m, '').lstrip
        current = "#{schema_comment}#{$/}#{$/}#{current}"
      else
        if m = current.reverse.match(/#{"#{$/}# Table: ".reverse}/m)
          offset = current.length - m.end(0) + 1
          unless current[offset..-1].match(/^[^#]/)
            # If Table: comment exists, and there are no
            # uncommented lines between it and the end of the file
            # then replace current comment instead of appending it
            current = current[0...offset].rstrip
          end
        end
        current += "#{$/}#{$/}#{schema_comment}"
      end

      if orig != current
        File.open(path, "wb") do |f|
          f.puts current
        end
      end
    end

    # The schema comment to use for this model.  
    # For all databases, includes columns, indexes, and foreign
    # key constraints in this table referencing other tables.
    # On PostgreSQL, also includes check constraints, triggers,
    # and foreign key constraints in other tables referencing this table.
    def schema_comment
      output = []
      output << "# Table: #{model.table_name}"

      meth = :"_schema_comment_#{model.db.database_type}"
      if respond_to?(meth, true)
        send(meth, output)
      else
        schema_comment_columns(output)
        schema_comment_indexes(output)
        schema_comment_foreign_keys(output)
      end

      output.join($/)
    end

    private

    # Returns an array of strings for each array of array, such that
    # each string is aligned and commented appropriately.  Example:
    #
    #   align([['abcdef', '1'], ['g', '123456']])
    #   # => ["#  abcdef  1", "#  g       123456"]
    def align(rows)
      cols = rows.first.length
      lengths = [0] * cols

      cols.times do |i|
        rows.each do |r|
          lengths[i] = r[i].length if r[i].length > lengths[i]
        end
      end

      rows.map do |r|
        "#  #{r.zip(lengths).map{|c, l| c.ljust(l)}.join(' | ')}".strip
      end
    end

    # Use the standard columns schema output, but use PostgreSQL specific
    # code for additional schema information.
    def _schema_comment_postgres(output)
      schema_comment_columns(output)
      oid = model.db.send(:regclass_oid, model.table_name)

      # These queries below are all based on the queries that psql
      # uses, captured using the -E option to psql.

      rows = model.db.fetch(<<SQL, :oid=>oid).all
SELECT c2.relname, i.indisprimary, i.indisunique, pg_catalog.pg_get_indexdef(i.indexrelid, 0, true)
FROM pg_catalog.pg_class c, pg_catalog.pg_class c2, pg_catalog.pg_index i
  LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
WHERE c.oid = :oid AND c.oid = i.indrelid AND i.indexrelid = c2.oid AND indisvalid
ORDER BY i.indisprimary DESC, i.indisunique DESC, c2.relname;
SQL
      unless rows.empty?
        output << "# Indexes:"
        rows = rows.map do |r|
          [r[:relname], "#{"PRIMARY KEY " if r[:indisprimary]}#{"UNIQUE " if r[:indisunique] && !r[:indisprimary]}#{r[:pg_get_indexdef].match(/USING (.+)\z/m)[1]}"]
        end
        output.concat(align(rows))
      end

      rows = model.db.fetch(<<SQL, :oid=>oid).all
SELECT r.conname, pg_catalog.pg_get_constraintdef(r.oid, true)
FROM pg_catalog.pg_constraint r
WHERE r.conrelid = :oid AND r.contype = 'c'
ORDER BY 1;
SQL
      unless rows.empty?
        output << "# Check constraints:"
        rows = rows.map do |r|
          [r[:conname], r[:pg_get_constraintdef].match(/CHECK (.+)\z/m)[1]]
        end
        output.concat(align(rows))
      end

      rows = model.db.fetch(<<SQL, :oid=>oid).all
SELECT conname,
  pg_catalog.pg_get_constraintdef(r.oid, true) as condef
FROM pg_catalog.pg_constraint r
WHERE r.conrelid = :oid AND r.contype = 'f' ORDER BY 1;
SQL
      unless rows.empty?
        output << "# Foreign key constraints:"
        rows = rows.map do |r|
          [r[:conname], r[:condef].match(/FOREIGN KEY (.+)\z/m)[1]]
        end
        output.concat(align(rows))
      end

      rows = model.db.fetch(<<SQL, :oid=>oid).all
SELECT conname, conrelid::pg_catalog.regclass,
  pg_catalog.pg_get_constraintdef(c.oid, true) as condef
FROM pg_catalog.pg_constraint c
WHERE c.confrelid = :oid AND c.contype = 'f' ORDER BY 2, 1;
SQL
      unless rows.empty?
        output << "# Referenced By:"
        rows = rows.map do |r|
          [r[:conrelid], r[:conname], r[:condef].match(/FOREIGN KEY (.+)\z/m)[1]]
        end
        output.concat(align(rows))
      end

      rows = model.db.fetch(<<SQL, :oid=>oid).all
SELECT t.tgname, pg_catalog.pg_get_triggerdef(t.oid, true), t.tgenabled, t.tgisinternal
FROM pg_catalog.pg_trigger t
WHERE t.tgrelid = :oid AND (NOT t.tgisinternal OR (t.tgisinternal AND t.tgenabled = 'D'))
ORDER BY 1;
SQL
      unless rows.empty?
        output << "# Triggers:"
        rows = rows.map do |r|
          [r[:tgname], r[:pg_get_triggerdef].match(/((?:BEFORE|AFTER) .+)\z/m)[1]]
        end
        output.concat(align(rows))
      end
    end

    # The standard column schema information to output.
    def schema_comment_columns(output)
      if cpk = model.primary_key.is_a?(Array)
        output << "# Primary Key: (#{model.primary_key.join(', ')})"
      end
      output << "# Columns:"
      rows = model.columns.map do |col|
        sch = model.db_schema[col]
        [col.to_s, sch[:db_type], "#{"PRIMARY KEY #{"AUTOINCREMENT " if sch[:auto_increment] && model.db.database_type != :postgres}" if sch[:primary_key] && !cpk}#{"NOT NULL " if sch[:allow_null] == false && !sch[:primary_key]}#{"DEFAULT #{sch[:default]}" if sch[:default]}#{"GENERATED BY DEFAULT AS IDENTITY" if sch[:auto_increment] && !sch[:default] && model.db.database_type == :postgres && model.db.server_version >= 100000}"]
      end
      output.concat(align(rows))
    end

    # The standard index information to output.
    def schema_comment_indexes(output)
      unless (indexes = model.db.indexes(model.table_name)).empty?
        output << "# Indexes:"
        rows = indexes.map do |name, metadata|
          [name.to_s, "#{'UNIQUE ' if metadata[:unique]}(#{metadata[:columns].join(', ')})"]
        end
        output.concat(align(rows).sort)
      end
    end

    # The standard foreign key information to output.
    def schema_comment_foreign_keys(output)
      unless (fks = model.db.foreign_key_list(model.table_name)).empty?
        output << "# Foreign key constraints:"
        rows = fks.map do |fk|
          ["(#{fk[:columns].join(', ')}) REFERENCES #{fk[:table]}#{"(#{fk[:key].join(', ')})" if fk[:key]}"]
        end
        output.concat(align(rows).sort)
      end
    end
  end
end
