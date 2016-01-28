require 'rubygems'
require 'fileutils'
require File.join(File.dirname(File.expand_path(__FILE__)), '../lib/sequel/annotate')
require 'minitest/autorun'

pg_user = ENV['PGUSER'] || 'postgres'
db_name = ENV['SEQUEL_ANNOTATE_DB'] || 'sequel-annotate_spec'
system("dropdb", "-U", pg_user, db_name)
system("createdb", "-U", pg_user, db_name)
DB = Sequel.postgres(db_name, :user=>pg_user)
SDB = Sequel.sqlite

[DB, SDB].each do |db|
  db.create_table :categories do
    primary_key :id
    String :name, :unique=>true, :null=>false
  end

  db.create_table :manufacturers do
    String :name
    String :location
    primary_key [:name, :location]
  end

  db.create_table :items do
    primary_key :id
    foreign_key :category_id, :categories, :null => false
    foreign_key [:manufacturer_name, :manufacturer_location], :manufacturers

    String :manufacturer_name, :size => 50
    String :manufacturer_location
    TrueClass :in_stock, :default => false
    String :name, :default => "John"
    Float  :price, :default => 0

    constraint :pos_id, Sequel.expr(:id) > 0

    index [:manufacturer_name, :manufacturer_location], :name=>:name, :unique=>true
    index [:manufacturer_name], :name=>:manufacturer_name
  end
end

DB.run <<SQL
CREATE FUNCTION valid_price() RETURNS trigger AS $emp_stamp$
    BEGIN
        -- Check that empname and salary are given
        IF NEW.price > 1000000 THEN
            RAISE EXCEPTION 'price is too high';
        END IF;
        RETURN NEW;
    END;
$emp_stamp$ LANGUAGE plpgsql;
SQL

DB.run <<SQL
CREATE TRIGGER valid_price BEFORE INSERT OR UPDATE ON items
    FOR EACH ROW EXECUTE PROCEDURE valid_price();
SQL

class ::Item < Sequel::Model; end
class ::Category < Sequel::Model; end
class ::Manufacturer < Sequel::Model; end
class ::SItem < Sequel::Model(SDB[:items]); end
class ::SCategory < Sequel::Model(SDB[:categories]); end
class ::SManufacturer < Sequel::Model(SDB[:manufacturers]); end


describe Sequel::Annotate do
  before do
    Dir.mkdir('spec/tmp') unless File.directory?('spec/tmp')
  end
  after do
    Dir['spec/tmp/*.rb'].each{|f| File.delete(f)}
  end

  it "#schema_info should return the model schema comment" do
    Sequel::Annotate.new(Item).schema_comment.must_equal((<<OUTPUT).chomp)
# Table: items
# Columns:
#  id                    | integer               | PRIMARY KEY DEFAULT nextval('items_id_seq'::regclass)
#  category_id           | integer               | NOT NULL
#  manufacturer_name     | character varying(50) |
#  manufacturer_location | text                  |
#  in_stock              | boolean               | DEFAULT false
#  name                  | text                  | DEFAULT 'John'::text
#  price                 | double precision      | DEFAULT 0
# Indexes:
#  items_pkey        | PRIMARY KEY btree (id)
#  name              | UNIQUE btree (manufacturer_name, manufacturer_location)
#  manufacturer_name | btree (manufacturer_name)
# Check constraints:
#  pos_id | (id > 0)
# Foreign key constraints:
#  items_category_id_fkey       | (category_id) REFERENCES categories(id)
#  items_manufacturer_name_fkey | (manufacturer_name, manufacturer_location) REFERENCES manufacturers(name, location)
# Triggers:
#  valid_price | BEFORE INSERT OR UPDATE ON items FOR EACH ROW EXECUTE PROCEDURE valid_price()
OUTPUT

    Sequel::Annotate.new(Category).schema_comment.must_equal((<<OUTPUT).chomp)
# Table: categories
# Columns:
#  id   | integer | PRIMARY KEY DEFAULT nextval('categories_id_seq'::regclass)
#  name | text    | NOT NULL
# Indexes:
#  categories_pkey     | PRIMARY KEY btree (id)
#  categories_name_key | UNIQUE btree (name)
# Referenced By:
#  items | items_category_id_fkey | (category_id) REFERENCES categories(id)
OUTPUT

    Sequel::Annotate.new(Manufacturer).schema_comment.must_equal((<<OUTPUT).chomp)
# Table: manufacturers
# Primary Key: (name, location)
# Columns:
#  name     | text |
#  location | text |
# Indexes:
#  manufacturers_pkey | PRIMARY KEY btree (name, location)
# Referenced By:
#  items | items_manufacturer_name_fkey | (manufacturer_name, manufacturer_location) REFERENCES manufacturers(name, location)
OUTPUT

    Sequel::Annotate.new(SItem).schema_comment.must_equal((<<OUTPUT).chomp)
# Table: items
# Columns:
#  id                    | integer          | PRIMARY KEY AUTOINCREMENT
#  category_id           | integer          | NOT NULL
#  manufacturer_name     | varchar(50)      |
#  manufacturer_location | varchar(255)     |
#  in_stock              | boolean          | DEFAULT 0
#  name                  | varchar(255)     | DEFAULT 'John'
#  price                 | double precision | DEFAULT 0
# Indexes:
#  manufacturer_name | (manufacturer_name)
#  name              | UNIQUE (manufacturer_name, manufacturer_location)
# Foreign key constraints:
#  (category_id) REFERENCES categories
#  (manufacturer_name, manufacturer_location) REFERENCES manufacturers
OUTPUT

    Sequel::Annotate.new(SCategory).schema_comment.must_equal((<<OUTPUT).chomp)
# Table: categories
# Columns:
#  id   | integer      | PRIMARY KEY AUTOINCREMENT
#  name | varchar(255) | NOT NULL
OUTPUT

    Sequel::Annotate.new(SManufacturer).schema_comment.must_equal((<<OUTPUT).chomp)
# Table: manufacturers
# Primary Key: (name, location)
# Columns:
#  name     | varchar(255) |
#  location | varchar(255) |
OUTPUT
  end

  it "#annotate should annotate the file comment" do
    FileUtils.cp(Dir['spec/unannotated/*.rb'], 'spec/tmp')

    [Item, Category, Manufacturer, SItem, SCategory, SManufacturer].each do |model|
      filename = model.name.downcase
      2.times do
        Sequel::Annotate.new(model).annotate("spec/tmp/#{filename}.rb")
        File.read("spec/tmp/#{filename}.rb").must_equal File.read("spec/annotated/#{filename}.rb")
      end
    end
  end

  it ".annotate should annotate all files given" do
    FileUtils.cp(Dir['spec/unannotated/*.rb'], 'spec/tmp')

    2.times do
      Sequel::Annotate.annotate(Dir["spec/tmp/*.rb"])
      [Item, Category, Manufacturer, SItem, SCategory, SManufacturer].each do |model|
        filename = model.name.downcase
        File.read("spec/tmp/#{filename}.rb").must_equal File.read("spec/annotated/#{filename}.rb")
      end
    end
  end
end
