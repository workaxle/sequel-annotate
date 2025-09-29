# frozen_string_literal: true

# These tasks are added to the project when you install sequel-annotate
# They automatically run annotations after Sequel migrations

# List of Sequel migration tasks to hook into
migration_tasks = %w[
  db:migrate
  db:migrate:up
  db:migrate:down
  db:migrate:redo
  db:rollback
  db:reset
]

# Also hook into Rails db tasks if using Rails
if defined?(Rails)
  migration_tasks.concat(%w[
    db:setup
    db:schema:load
    db:structure:load
  ])
end

# Enhance each migration task to run annotations afterward
migration_tasks.each do |task|
  next unless Rake::Task.task_defined?(task)

  Rake::Task[task].enhance do
    # Run annotations after the last task in the chain completes
    Rake::Task[Rake.application.top_level_tasks.last].enhance do
      Sequel::Annotate::Migration.update_annotations
    end
  end
end

module Sequel
  module Annotate
    class Migration
      @@working = false

      class << self
        def update_annotations
          return if @@working || skip_annotations?

          @@working = true

          begin
            update_models
          ensure
            @@working = false
          end
        end

        def update_models
          # Check for the annotate task in various locations
          annotate_task = find_annotate_task

          if annotate_task
            puts "Annotating models..." if verbose?
            Rake::Task[annotate_task].invoke
          else
            # If no rake task exists, run annotation directly
            run_annotation_directly
          end
        end

        private

        def find_annotate_task
          %w[annotate sequel:annotate db:annotate].each do |task_name|
            return task_name if Rake::Task.task_defined?(task_name)
          end
          nil
        end

        def run_annotation_directly
          return unless defined?(Sequel::Annotate)

          begin
            require 'sequel/annotate'

            # Load configuration if it exists
            config_file = Rails.root.join('.sequel_annotate.yml') if defined?(Rails)
            config_file ||= '.sequel_annotate.yml'

            options = if File.exist?(config_file)
                       require 'yaml'
                       YAML.load_file(config_file)
                     else
                       default_options
                     end

            # Get Sequel database connection
            db = if defined?(Sequel::Model) && Sequel::Model.db
                   Sequel::Model.db
                 elsif defined?(DB)
                   DB
                 else
                   nil
                 end

            return unless db

            puts "Auto-annotating Sequel models..." if verbose?

            # Run the annotation
            Sequel::Annotate.annotate(db, options)

            puts "Models annotated successfully" if verbose?
          rescue StandardError => e
            puts "Error annotating models: #{e.message}" if verbose?
          end
        end

        def default_options
          {
            position: :before,
            exclude: [],
            include: [],
            rubocop: true,
            border: false
          }
        end

        def skip_annotations?
          ENV['SKIP_ANNOTATIONS'] == 'true' ||
          ENV['ANNOTATE_SKIP_ON_DB_MIGRATE'] == 'true'
        end

        def verbose?
          ENV['VERBOSE'] == 'true' || ENV['ANNOTATE_VERBOSE'] == 'true'
        end
      end
    end
  end
end