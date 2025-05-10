require "rake"
require "rake/clean"

CLEAN.include ["sequel-annotate-*.gem", "rdoc"]

desc "Build sequel-annotate gem"
task :package=>[:clean] do |p|
  sh %{#{FileUtils::RUBY} -S gem build sequel-annotate.gemspec}
end

### Specs

desc "Run specs"
task :spec do
  sh "#{FileUtils::RUBY} #{"-w" if RUBY_VERSION >= '3'} #{'-W:strict_unused_block' if RUBY_VERSION >= '3.4'} -I lib spec/sequel-annotate_spec.rb"
end

task :default => :spec

desc "Run specs with coverage"
task :spec_cov do
  ENV["COVERAGE"] = "1"
  Rake::Task['spec'].invoke
  ENV.delete('COVERAGE')
end

desc "Run specs in CI"
task :spec_ci do
  ENV['SEQUEL_ANNOTATE_SPEC_CI'] = '1'
  if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
    ENV['SEQUEL_ANNOTATE_SPEC_POSTGRES_URL'] = "jdbc:postgresql://localhost/?user=postgres&password=postgres"
  else
    ENV['SEQUEL_ANNOTATE_SPEC_POSTGRES_URL'] = "postgres://localhost/?user=postgres&password=postgres"
  end
  Rake::Task['spec'].invoke
end

### RDoc

desc "Generate rdoc"
task :rdoc do
  rdoc_dir = "rdoc"
  rdoc_opts = ["--line-numbers", "--inline-source", '--title', 'sequel-annotate: Annotate Sequel models with schema information']

  begin
    gem 'hanna'
    rdoc_opts.concat(['-f', 'hanna'])
  rescue Gem::LoadError
  end

  rdoc_opts.concat(['--main', 'README.rdoc', "-o", rdoc_dir] +
    %w"README.rdoc CHANGELOG MIT-LICENSE" +
    Dir["lib/**/*.rb"]
  )

  FileUtils.rm_rf(rdoc_dir)

  require "rdoc"
  RDoc::RDoc.new.document(rdoc_opts)
end
