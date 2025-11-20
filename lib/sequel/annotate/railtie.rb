# frozen_string_literal: true

require 'rails/railtie'

module Sequel
  class Annotate
    class Railtie < Rails::Railtie
      railtie_name :sequel_annotate

      rake_tasks do
        load File.expand_path('../../tasks/sequel_annotate_migrate.rake', __dir__)
      end

      generators do
        require_relative '../../generators/sequel_annotate/install/install_generator'
      end
    end
  end
end