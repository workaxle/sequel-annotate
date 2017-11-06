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
  sh "#{FileUtils::RUBY} -I lib spec/sequel-annotate_spec.rb"
end

task :default => :spec

### RDoc

RDOC_DEFAULT_OPTS = ["--quiet", "--line-numbers", "--inline-source", '--title', 'sequel-annotate: Annotate Sequel models with schema information']

begin
  gem 'rdoc'
  gem 'hanna-nouveau'
  RDOC_DEFAULT_OPTS.concat(['-f', 'hanna'])
rescue Gem::LoadError
end

rdoc_task_class = begin
  require "rdoc/task"
  RDoc::Task
rescue LoadError
  require "rake/rdoctask"
  Rake::RDocTask
end

RDOC_OPTS = RDOC_DEFAULT_OPTS + ['--main', 'README.rdoc']

rdoc_task_class.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += RDOC_OPTS
  rdoc.rdoc_files.add %w"README.rdoc CHANGELOG MIT-LICENSE lib/**/*.rb"
end

