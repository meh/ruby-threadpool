Gem::Specification.new {|s|
	s.name         = 'threadpool'
	s.version      = '0.0.1.2'
	s.author       = 'meh.'
	s.email        = 'meh@paranoici.org'
	s.homepage     = 'http://github.com/meh/threadpool'
	s.platform     = Gem::Platform::RUBY
	s.summary      = 'A simple no-wasted-resources thread pool implementation.'

	s.files         = `git ls-files`.split("\n")
	s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
	s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
	s.require_paths = ['lib']
}
