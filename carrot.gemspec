Gem::Specification.new do |s|
  s.name = %q{carrot}
  s.version = "0.7.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Amos Elliston"]
  s.date = %q{2009-08-26}
  s.description = %q{TODO}
  s.email = %q{amos@geni.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.markdown"
  ]
  s.files = [
    ".gitignore",
     "LICENSE",
     "README.markdown",
     "Rakefile",
     "VERSION.yml",
     "carrot.gemspec",
     "lib/amqp/buffer.rb",
     "lib/amqp/exchange.rb",
     "lib/amqp/frame.rb",
     "lib/amqp/header.rb",
     "lib/amqp/protocol.rb",
     "lib/amqp/queue.rb",
     "lib/amqp/server.rb",
     "lib/amqp/spec.rb",
     "lib/carrot.rb",
     "lib/examples/simple_pop.rb",
     "protocol/amqp-0.8.json",
     "protocol/amqp-0.8.xml",
     "protocol/codegen.rb",
     "protocol/doc.txt",
     "test/carrot_test.rb",
     "test/test_helper.rb"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/famoseagle/carrot}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{TODO}
  s.test_files = [
    "test/carrot_test.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
    else
    end
  else
  end
end
