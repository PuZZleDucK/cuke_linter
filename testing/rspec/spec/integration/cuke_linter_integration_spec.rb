require_relative '../../../../environments/rspec_env'

RSpec.describe CukeLinter do

  let(:test_model_tree) { CukeLinter::ModelFactory.generate_lintable_model }
  let(:test_linters) { [CukeLinter::LinterFactory.generate_fake_linter] }
  let(:test_formatters) { [[CukeLinter::FormatterFactory.generate_fake_formatter, "#{CukeLinter::FileHelper::create_directory}/junk_output_file.txt"]] }
  let(:linting_options) { { model_trees: [test_model_tree], linters: test_linters, formatters: test_formatters } }


  it 'returns the un-formatted linting data when linting' do
    results = subject.lint(linting_options)

    expect(results).to eq([{ linter: 'FakeLinter', location: 'path_to_file:1', problem: 'FakeLinter problem' }])
  end

  it 'uses every formatter provided' do
    linting_options[:formatters] = [[CukeLinter::FormatterFactory.generate_fake_formatter(name: 'Formatter1')],
                                    [CukeLinter::FormatterFactory.generate_fake_formatter(name: 'Formatter2')]]

    expect { subject.lint(linting_options) }.to output("Formatter1: FakeLinter problem: path_to_file:1\nFormatter2: FakeLinter problem: path_to_file:1\n").to_stdout
  end

  it "uses the 'pretty' formatter if none are provided" do
    linting_options.delete(:formatters)

    expect { subject.lint(linting_options) }.to output(['FakeLinter',
                                                        '  FakeLinter problem',
                                                        '    path_to_file:1',
                                                        '',
                                                        '1 issues found',
                                                        ''].join("\n")).to_stdout
  end

  it 'outputs formatted linting data to the provided output location' do
    output_path                  = "#{CukeLinter::FileHelper::create_directory}/output.txt"
    linting_options[:formatters] = [[CukeLinter::FormatterFactory.generate_fake_formatter(name: 'Formatter1'),
                                     output_path]]

    expect { subject.lint(linting_options) }.to_not output.to_stdout
    expect(File.read(output_path)).to eq("Formatter1: FakeLinter problem: path_to_file:1\n")
  end

  it 'outputs formatted data to STDOUT if not location is provided' do
    linting_options[:formatters] = [[CukeLinter::FormatterFactory.generate_fake_formatter(name: 'Formatter1')]]

    expect { subject.lint(linting_options) }.to output("Formatter1: FakeLinter problem: path_to_file:1\n").to_stdout
  end

  context 'with only model trees' do

    before(:each) do
      child_model      = CukeLinter::ModelFactory.generate_lintable_model(source_line: 3)
      parent_model     = CukeLinter::ModelFactory.generate_lintable_model(source_line: 5, children: [child_model])
      multi_node_tree  = parent_model
      single_node_tree = CukeLinter::ModelFactory.generate_lintable_model(source_line: 7)

      linting_options[:model_trees] = [single_node_tree, multi_node_tree]
      linting_options.delete(:file_paths)
    end

    it 'lints every model in each model tree' do
      results = subject.lint(linting_options)

      expect(results).to match_array([{ linter: 'FakeLinter', location: 'path_to_file:3', problem: 'FakeLinter problem' },
                                      { linter: 'FakeLinter', location: 'path_to_file:5', problem: 'FakeLinter problem' },
                                      { linter: 'FakeLinter', location: 'path_to_file:7', problem: 'FakeLinter problem' }])
    end

  end

  context 'with only file paths' do

    before(:each) do
      @a_feature_file    = CukeLinter::FileHelper::create_file(text: "\nFeature:", extension: '.feature')
      a_non_feature_file = CukeLinter::FileHelper::create_file(text: 'Some text', extension: '.foo')
      @a_directory       = CukeLinter::FileHelper::create_directory
      File.write("#{@a_directory}/test_feature.feature", "Feature:")

      linting_options[:file_paths] = [@a_feature_file, a_non_feature_file, @a_directory]
      linting_options.delete(:model_trees)
    end

    it 'lints every model in each path' do
      results = subject.lint(linting_options)

      expect(results).to match_array([{ linter: 'FakeLinter', location: @a_directory, problem: 'FakeLinter problem' },
                                      { linter: 'FakeLinter', location: "#{@a_directory}/test_feature.feature", problem: 'FakeLinter problem' },
                                      { linter: 'FakeLinter', location: "#{@a_directory}/test_feature.feature:1", problem: 'FakeLinter problem' },
                                      { linter: 'FakeLinter', location: @a_feature_file, problem: 'FakeLinter problem' },
                                      { linter: 'FakeLinter', location: "#{@a_feature_file}:2", problem: 'FakeLinter problem' }])
    end

  end

  context 'with both model trees and file paths' do

    before(:each) do
      a_model         = CukeLinter::ModelFactory.generate_lintable_model(source_line: 3)
      @a_feature_file = CukeLinter::FileHelper::create_file(text: 'Feature:', extension: '.feature')

      linting_options[:model_trees] = [a_model]
      linting_options[:file_paths]  = [@a_feature_file]
    end


    it 'lints every model in each model tree and file path' do
      results = subject.lint(linting_options)

      expect(results).to match_array([{ linter: 'FakeLinter', location: 'path_to_file:3', problem: 'FakeLinter problem' },
                                      { linter: 'FakeLinter', location: @a_feature_file, problem: 'FakeLinter problem' },
                                      { linter: 'FakeLinter', location: "#{@a_feature_file}:1", problem: 'FakeLinter problem' }])
    end

  end

  context 'with neither model trees or file paths' do

    before(:each) do
      linting_options.delete(:model_trees)
      linting_options.delete(:file_paths)
    end

    it 'models the current directory' do
      test_dir = CukeLinter::FileHelper::create_directory
      File.write("#{test_dir}/test_feature.feature", "Feature:")

      Dir.chdir(test_dir) do
        @results = subject.lint(linting_options)
      end

      # There should be 3 models to lint: the directory, the feature file, and the feature
      expect(@results.count).to eq(3)
    end

  end

  it 'uses evey linter provided' do
    linting_options[:linters] = [CukeLinter::LinterFactory.generate_fake_linter(name: 'FakeLinter1'),
                                 CukeLinter::LinterFactory.generate_fake_linter(name: 'FakeLinter2')]

    results = subject.lint(linting_options)

    expect(results).to match_array([{ linter: 'FakeLinter1', location: 'path_to_file:1', problem: 'FakeLinter1 problem' },
                                    { linter: 'FakeLinter2', location: 'path_to_file:1', problem: 'FakeLinter2 problem' }])
  end

  it 'uses all registered linters if none are provided', :linter_registration do
    CukeLinter.clear_registered_linters
    CukeLinter.register_linter(linter: CukeLinter::LinterFactory.generate_fake_linter(name: 'FakeLinter1'), name: 'FakeLinter1')
    CukeLinter.register_linter(linter: CukeLinter::LinterFactory.generate_fake_linter(name: 'FakeLinter2'), name: 'FakeLinter2')
    CukeLinter.register_linter(linter: CukeLinter::LinterFactory.generate_fake_linter(name: 'FakeLinter3'), name: 'FakeLinter3')

    begin
      linting_options.delete(:linters)
      results = subject.lint(linting_options)

      expect(results).to match_array([{ linter: 'FakeLinter1', location: 'path_to_file:1', problem: 'FakeLinter1 problem' },
                                      { linter: 'FakeLinter2', location: 'path_to_file:1', problem: 'FakeLinter2 problem' },
                                      { linter: 'FakeLinter3', location: 'path_to_file:1', problem: 'FakeLinter3 problem' }])
    ensure
      CukeLinter.reset_linters
    end
  end

  it 'includes the name of the linter in the linting data' do
    linting_options[:linters] = [CukeLinter::LinterFactory.generate_fake_linter(name: 'FakeLinter1'),
                                 CukeLinter::LinterFactory.generate_fake_linter(name: 'FakeLinter2')]

    results = subject.lint(linting_options)

    expect(results).to match_array([{ linter: 'FakeLinter1', location: 'path_to_file:1', problem: 'FakeLinter1 problem' },
                                    { linter: 'FakeLinter2', location: 'path_to_file:1', problem: 'FakeLinter2 problem' }])
  end

  it 'has a default set of registered linters' do
    expect(subject.registered_linters.keys).to include('BackgroundDoesMoreThanSetupLinter')
    expect(subject.registered_linters['BackgroundDoesMoreThanSetupLinter']).to be_a(CukeLinter::BackgroundDoesMoreThanSetupLinter)
    expect(subject.registered_linters.keys).to include('ElementWithTooManyTagsLinter')
    expect(subject.registered_linters['ElementWithTooManyTagsLinter']).to be_a(CukeLinter::ElementWithTooManyTagsLinter)
    expect(subject.registered_linters.keys).to include('ExampleWithoutNameLinter')
    expect(subject.registered_linters['ExampleWithoutNameLinter']).to be_a(CukeLinter::ExampleWithoutNameLinter)
    expect(subject.registered_linters.keys).to include('FeatureWithTooManyDifferentTagsLinter')
    expect(subject.registered_linters['FeatureWithTooManyDifferentTagsLinter']).to be_a(CukeLinter::FeatureWithTooManyDifferentTagsLinter)
    expect(subject.registered_linters.keys).to include('FeatureWithoutDescriptionLinter')
    expect(subject.registered_linters['FeatureWithoutDescriptionLinter']).to be_a(CukeLinter::FeatureWithoutDescriptionLinter)
    expect(subject.registered_linters.keys).to include('FeatureWithoutNameLinter')
    expect(subject.registered_linters['FeatureWithoutNameLinter']).to be_a(CukeLinter::FeatureWithoutNameLinter)
    expect(subject.registered_linters.keys).to include('FeatureWithoutScenariosLinter')
    expect(subject.registered_linters['FeatureWithoutScenariosLinter']).to be_a(CukeLinter::FeatureWithoutScenariosLinter)
    expect(subject.registered_linters.keys).to include('OutlineWithSingleExampleRowLinter')
    expect(subject.registered_linters['OutlineWithSingleExampleRowLinter']).to be_a(CukeLinter::OutlineWithSingleExampleRowLinter)
    expect(subject.registered_linters.keys).to include('ScenarioWithBadNameLinter')
    expect(subject.registered_linters['ScenarioWithBadNameLinter']).to be_a(CukeLinter::ScenarioWithBadNameLinter)
    expect(subject.registered_linters.keys).to include('SingleTestBackgroundLinter')
    expect(subject.registered_linters['SingleTestBackgroundLinter']).to be_a(CukeLinter::SingleTestBackgroundLinter)
    expect(subject.registered_linters.keys).to include('StepWithEndPeriodLinter')
    expect(subject.registered_linters['StepWithEndPeriodLinter']).to be_a(CukeLinter::StepWithEndPeriodLinter)
    expect(subject.registered_linters.keys).to include('StepWithTooManyCharactersLinter')
    expect(subject.registered_linters['StepWithTooManyCharactersLinter']).to be_a(CukeLinter::StepWithTooManyCharactersLinter)
    expect(subject.registered_linters.keys).to include('TestShouldUseBackgroundLinter')
    expect(subject.registered_linters['TestShouldUseBackgroundLinter']).to be_a(CukeLinter::TestShouldUseBackgroundLinter)
    expect(subject.registered_linters.keys).to include('TestWithActionStepAsFinalStepLinter')
    expect(subject.registered_linters['TestWithActionStepAsFinalStepLinter']).to be_a(CukeLinter::TestWithActionStepAsFinalStepLinter)
    expect(subject.registered_linters.keys).to include('TestWithNoActionStepLinter')
    expect(subject.registered_linters['TestWithNoActionStepLinter']).to be_a(CukeLinter::TestWithNoActionStepLinter)
    expect(subject.registered_linters.keys).to include('TestWithNoNameLinter')
    expect(subject.registered_linters['TestWithNoNameLinter']).to be_a(CukeLinter::TestWithNoNameLinter)
    expect(subject.registered_linters.keys).to include('TestWithNoVerificationStepLinter')
    expect(subject.registered_linters['TestWithNoVerificationStepLinter']).to be_a(CukeLinter::TestWithNoVerificationStepLinter)
    expect(subject.registered_linters.keys).to include('TestWithSetupStepAfterActionStepLinter')
    expect(subject.registered_linters['TestWithSetupStepAfterActionStepLinter']).to be_a(CukeLinter::TestWithSetupStepAfterActionStepLinter)
    expect(subject.registered_linters.keys).to include('TestWithSetupStepAfterVerificationStepLinter')
    expect(subject.registered_linters['TestWithSetupStepAfterVerificationStepLinter']).to be_a(CukeLinter::TestWithSetupStepAfterVerificationStepLinter)
    expect(subject.registered_linters.keys).to include('TestWithSetupStepAsFinalStepLinter')
    expect(subject.registered_linters['TestWithSetupStepAsFinalStepLinter']).to be_a(CukeLinter::TestWithSetupStepAsFinalStepLinter)
    expect(subject.registered_linters.keys).to include('TestWithTooManyStepsLinter')
    expect(subject.registered_linters['TestWithTooManyStepsLinter']).to be_a(CukeLinter::TestWithTooManyStepsLinter)
  end

  it 'returns to its default set of linters after being reset' do
    original_names        = CukeLinter.registered_linters.keys
    original_linter_types = CukeLinter.registered_linters.values.map(&:class)
    new_linter            = CukeLinter::LinterFactory.generate_fake_linter

    CukeLinter.register_linter(linter: new_linter, name: 'FakeLinter')
    CukeLinter.reset_linters

    expect(CukeLinter.registered_linters.keys).to eq(original_names)
    expect(CukeLinter.registered_linters.values.map(&:class)).to eq(original_linter_types)
  end

  # To protect against someone modifying them
  it 'does not reuse the old linting objects when resetting to the default linters' do
    original_linter_ids = CukeLinter.registered_linters.values.map(&:object_id)

    CukeLinter.reset_linters

    expect(CukeLinter.registered_linters.values.map(&:object_id)).to_not match_array(original_linter_ids)
  end

  it 'can handle a mixture of problematic and non-problematic models' do
    linting_options[:linters] = [CukeLinter::LinterFactory.generate_fake_linter(finds_problems: true),
                                 CukeLinter::LinterFactory.generate_fake_linter(finds_problems: false)]

    expect { subject.lint(linting_options) }.to_not raise_error
  end

end
