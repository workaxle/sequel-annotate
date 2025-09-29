spec = Gem::Specification.new do |s|
  s.name = 'sequel-annotate'
  s.version = '1.7.1'
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG", "MIT-LICENSE"]
  s.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'sequel-annotate: Annotate Sequel models with schema information', '--main', 'README.rdoc']
  s.license = "MIT"
  s.summary = "Annotate Sequel models with schema information"
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.homepage = "http://github.com/workaxle/sequel-annotate"
  s.files = %w(MIT-LICENSE CHANGELOG README.rdoc Rakefile) + Dir["{spec,lib}/**/*.{rb,rake,yml}"]
  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/jeremyevans/sequel-annotate/issues',
    'changelog_uri'     => 'https://github.com/jeremyevans/sequel-annotate/blob/master/CHANGELOG',
    'source_code_uri'   => 'https://github.com/jeremyevans/sequel-annotate',
  }
  s.required_ruby_version = ">= 1.8.7"
  s.description = <<END
sequel-annotate annotates Sequel models with schema information.  By
default, it includes information on columns, indexes, and foreign key
constraints for the current table.

On PostgreSQL, this includes more advanced information, including
check constraints, triggers, comments, and foreign keys constraints for other
tables that reference the current table.
END
  s.add_dependency('sequel', '>= 4')
  s.add_development_dependency('minitest', '>= 5')
  s.add_development_dependency "minitest-global_expectations"
  s.add_development_dependency('pg')
  s.add_development_dependency('sqlite3')
end
