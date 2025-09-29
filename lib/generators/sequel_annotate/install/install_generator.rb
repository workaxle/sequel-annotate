# frozen_string_literal: true

require 'rails/generators/base'

module SequelAnnotate
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc "Installs sequel-annotate and sets up automatic annotation on migrations"

      def create_configuration_file
        template 'sequel_annotate.yml', '.sequel_annotate.yml'
      end

      def create_rake_task
        template 'auto_annotate_models.rake', 'lib/tasks/auto_annotate_models.rake'
      end

      def add_development_dependency
        return if gemfile_contains_sequel_annotate?

        say_status :gemfile, "Adding sequel-annotate to Gemfile"

        gem_content = <<~RUBY

          # Automatically annotate models after migrations
          gem 'sequel-annotate', github: 'workaxle/sequel-annotate', branch: 'master', group: :development
        RUBY

        append_to_file 'Gemfile', gem_content
      end

      def instructions
        say <<~INSTRUCTIONS

          ✅ sequel-annotate has been installed!

          The gem will now automatically annotate your models after running migrations.

          Configuration options can be adjusted in .sequel_annotate.yml

          To skip annotations for a specific migration, run:
            SKIP_ANNOTATIONS=true rails db:migrate

          To manually annotate models, run:
            rake db:annotate

        INSTRUCTIONS
      end

      private

      def gemfile_contains_sequel_annotate?
        File.read('Gemfile').include?('sequel-annotate')
      end
    end
  end
end