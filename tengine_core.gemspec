# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{tengine_core}
  s.version = "0.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{t-akima}]
  s.date = %q{2011-09-14}
  s.description = %q{tengine_core is a framework/engine to support distributed processing}
  s.email = %q{akima@nautilus-technologies.com}
  s.executables = [%q{tengined}]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/tengined",
    "examples/VERSION",
    "examples/uc01_execute_processing_for_event.rb",
    "examples/uc02_fire_another_event.rb",
    "examples/uc03_2handlers_for_1event.rb",
    "examples/uc08_if_both_a_and_b_occurs.rb",
    "examples/uc50_commit_event_at_first.rb",
    "examples/uc51_commit_event_at_first_submit.rb",
    "examples/uc52_commit_event_after_all_handler_submit.rb",
    "examples/uc52_never_commit_event_unless_all_handler_submit.rb",
    "examples/uc60_event_in_handler.rb",
    "examples/uc62_session_in_driver.rb",
    "examples/uc64_safety_countup.rb",
    "examples/uc70_driver_enabled_on_activation.rb",
    "examples/uc71_driver_disabled_on_activation.rb",
    "examples/uc80_raise_io_error.rb",
    "examples/uc81_raise_runtime_error.rb",
    "failure_examples/VERSION",
    "failure_examples/uc53_submit_outside_of_handler.rb",
    "failure_examples/uc61_event_outside_of_handler.rb",
    "failure_examples/uc63_session_outside_of_driver.rb",
    "lib/tengine/core.rb",
    "lib/tengine/core/bootstrap.rb",
    "lib/tengine/core/collection_accessible.rb",
    "lib/tengine/core/config.rb",
    "lib/tengine/core/connection_test/.gitignore",
    "lib/tengine/core/connection_test/fire_bar_on_foo.rb",
    "lib/tengine/core/driver.rb",
    "lib/tengine/core/driver/finder.rb",
    "lib/tengine/core/dsl_binder.rb",
    "lib/tengine/core/dsl_context.rb",
    "lib/tengine/core/dsl_dummy_context.rb",
    "lib/tengine/core/dsl_evaluator.rb",
    "lib/tengine/core/dsl_filter_def.rb",
    "lib/tengine/core/dsl_loader.rb",
    "lib/tengine/core/event.rb",
    "lib/tengine/core/event/finder.rb",
    "lib/tengine/core/event_wrapper.rb",
    "lib/tengine/core/handler.rb",
    "lib/tengine/core/handler_path.rb",
    "lib/tengine/core/io_to_logger.rb",
    "lib/tengine/core/kernel.rb",
    "lib/tengine/core/kernel_runtime.rb",
    "lib/tengine/core/method_traceable.rb",
    "lib/tengine/core/session.rb",
    "lib/tengine/core/session_wrapper.rb",
    "lib/tengine_core.rb",
    "spec/factories/tengine_core_drivers.rb",
    "spec/factories/tengine_core_events.rb",
    "spec/factories/tengine_core_handler_paths.rb",
    "spec/factories/tengine_core_handlers.rb",
    "spec/factories/tengine_core_sessions.rb",
    "spec/mongoid.yml",
    "spec/spec_helper.rb",
    "spec/tengine/core/bootstrap_spec.rb",
    "spec/tengine/core/config_spec.rb",
    "spec/tengine/core/config_spec/config_with_dir_load_path.yml",
    "spec/tengine/core/config_spec/config_with_file_load_path.yml",
    "spec/tengine/core/config_spec/log_config_spec.rb",
    "spec/tengine/core/driver_spec.rb",
    "spec/tengine/core/dsl_binder_spec.rb",
    "spec/tengine/core/dsl_context_spec.rb",
    "spec/tengine/core/dsl_loader_spec.rb",
    "spec/tengine/core/dsls/uc08_if_both_a_and_b_occurs_spec.rb",
    "spec/tengine/core/dsls/uc50_commit_event_at_first_spec.rb",
    "spec/tengine/core/dsls/uc52_commit_event_after_all_handler_submit_spec.rb",
    "spec/tengine/core/dsls/uc52_never_commit_event_unless_all_handler_submit_spec.rb",
    "spec/tengine/core/dsls/uc53_submit_outside_of_handler_spec.rb",
    "spec/tengine/core/dsls/uc60_event_in_handler_spec.rb",
    "spec/tengine/core/dsls/uc61_event_outside_of_handler_spec.rb",
    "spec/tengine/core/dsls/uc62_session_in_driver_spec.rb",
    "spec/tengine/core/dsls/uc63_session_outside_of_driver_spec.rb",
    "spec/tengine/core/dsls/uc64_safety_countup_spec.rb",
    "spec/tengine/core/dsls/uc70_driver_enabled_on_activation_spec.rb",
    "spec/tengine/core/dsls/uc71_driver_disabled_on_activation_spec.rb",
    "spec/tengine/core/dsls/uc80_raise_io_error_spec.rb",
    "spec/tengine/core/dsls/uc81_raise_runtime_error_spec.rb",
    "spec/tengine/core/event_spec.rb",
    "spec/tengine/core/handler_path_spec.rb",
    "spec/tengine/core/handler_spec.rb",
    "spec/tengine/core/io_to_logger_spec.rb",
    "spec/tengine/core/kernel_spec.rb",
    "spec/tengine/core/session_spec.rb",
    "tengine_core.gemspec",
    "tmp/log/.gitignore",
    "tmp/tengined_status/.gitignore"
  ]
  s.homepage = %q{http://github.com/akm/tengine_core}
  s.licenses = [%q{MIT}]
  s.require_paths = [%q{lib}]
  s.rubygems_version = %q{1.8.6}
  s.summary = %q{tengine_core is a framework/engine to support distributed processing}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, ["~> 3.1"])
      s.add_runtime_dependency(%q<activemodel>, ["~> 3.1"])
      s.add_runtime_dependency(%q<selectable_attr>, ["~> 0.3"])
      s.add_runtime_dependency(%q<mongoid>, ["~> 2.2"])
      s.add_runtime_dependency(%q<bson_ext>, ["~> 1.3"])
      s.add_runtime_dependency(%q<tengine_event>, ["~> 0.2"])
      s.add_runtime_dependency(%q<daemons>, ["~> 1.1"])
      s.add_development_dependency(%q<rspec>, ["~> 2.6"])
      s.add_development_dependency(%q<factory_girl>, ["~> 2.1"])
      s.add_development_dependency(%q<yard>, ["~> 0.7"])
      s.add_development_dependency(%q<ZenTest>, ["~> 4.4"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.4"])
    else
      s.add_dependency(%q<activesupport>, ["~> 3.1"])
      s.add_dependency(%q<activemodel>, ["~> 3.1"])
      s.add_dependency(%q<selectable_attr>, ["~> 0.3"])
      s.add_dependency(%q<mongoid>, ["~> 2.2"])
      s.add_dependency(%q<bson_ext>, ["~> 1.3"])
      s.add_dependency(%q<tengine_event>, ["~> 0.2"])
      s.add_dependency(%q<daemons>, ["~> 1.1"])
      s.add_dependency(%q<rspec>, ["~> 2.6"])
      s.add_dependency(%q<factory_girl>, ["~> 2.1"])
      s.add_dependency(%q<yard>, ["~> 0.7"])
      s.add_dependency(%q<ZenTest>, ["~> 4.4"])
      s.add_dependency(%q<bundler>, ["~> 1.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_dependency(%q<simplecov>, ["~> 0.4"])
    end
  else
    s.add_dependency(%q<activesupport>, ["~> 3.1"])
    s.add_dependency(%q<activemodel>, ["~> 3.1"])
    s.add_dependency(%q<selectable_attr>, ["~> 0.3"])
    s.add_dependency(%q<mongoid>, ["~> 2.2"])
    s.add_dependency(%q<bson_ext>, ["~> 1.3"])
    s.add_dependency(%q<tengine_event>, ["~> 0.2"])
    s.add_dependency(%q<daemons>, ["~> 1.1"])
    s.add_dependency(%q<rspec>, ["~> 2.6"])
    s.add_dependency(%q<factory_girl>, ["~> 2.1"])
    s.add_dependency(%q<yard>, ["~> 0.7"])
    s.add_dependency(%q<ZenTest>, ["~> 4.4"])
    s.add_dependency(%q<bundler>, ["~> 1.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    s.add_dependency(%q<simplecov>, ["~> 0.4"])
  end
end

