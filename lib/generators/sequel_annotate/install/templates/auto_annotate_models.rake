# frozen_string_literal: true

# Rake tasks for sequel-annotate
# Run these tasks to manually annotate models

namespace :db do
  desc 'Annotate Sequel models with schema information'
  task annotate: :environment do
    require 'sequel/annotate'

    # Load configuration
    config_file = Rails.root.join('.sequel_annotate.yml')
    options = if File.exist?(config_file)
                require 'yaml'
                YAML.load_file(config_file)
              else
                {}
              end

    # Convert string keys to symbols
    options = options.transform_keys(&:to_sym)

    # Get the Sequel database connection
    db = if defined?(Sequel::Model) && Sequel::Model.db
           Sequel::Model.db
         elsif defined?(DB)
           DB
         else
           raise "No Sequel database connection found"
         end

    puts "Annotating models..."
    Sequel::Annotate.annotate(db, options)
    puts "✅ Models annotated successfully"
  end

  desc 'Remove annotations from Sequel models'
  task deannotate: :environment do
    require 'sequel/annotate'

    # Load configuration
    config_file = Rails.root.join('.sequel_annotate.yml')
    options = if File.exist?(config_file)
                require 'yaml'
                YAML.load_file(config_file)
              else
                {}
              end

    # Convert string keys to symbols
    options = options.transform_keys(&:to_sym)

    # Get the Sequel database connection
    db = if defined?(Sequel::Model) && Sequel::Model.db
           Sequel::Model.db
         elsif defined?(DB)
           DB
         else
           raise "No Sequel database connection found"
         end

    puts "Removing annotations from models..."
    Sequel::Annotate.annotate(db, options.merge(remove: true))
    puts "✅ Annotations removed successfully"
  end
end

# Alias tasks for convenience
desc 'Alias for db:annotate'
task annotate: 'db:annotate'

desc 'Alias for db:deannotate'
task deannotate: 'db:deannotate'