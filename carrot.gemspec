Gem::Specification.new do |s|
  s.name = %q{carrot}
  s.version = "0.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Amos Elliston"]
  s.date = %q{2009-04-15}
  s.description = %q{TODO}
  s.email = %q{amos@geni.com}
  s.files = ["README.markdown", "VERSION.yml", "lib/amqp", "lib/amqp/buffer.rb", "lib/amqp/exchange.rb", "lib/amqp/frame.rb", "lib/amqp/header.rb", "lib/amqp/protocol.rb", "lib/amqp/queue.rb", "lib/amqp/server.rb", "lib/amqp/spec.rb", "lib/carrot.rb", "lib/examples", "lib/examples/simple_pop.rb", "test/carrot_test.rb", "test/test_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/famoseagle/carrot}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{TODO}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
    else
    end
  else
  end
end
