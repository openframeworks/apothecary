require 'yaml'

root = File.expand_path('../..', __dir__)
group = "${{ github.workflow }}-${{ startsWith(github.ref, 'refs/tags/') && github.run_id || github.event.pull_request.number || github.ref }}"
cancel = "${{ !startsWith(github.ref, 'refs/tags/') }}"
Dir["#{root}/.github/workflows/build*.yml"].each do |file|
  workflow = YAML.load_file(file)
  next unless workflow['concurrency']
  raise "Unstable group: #{file}" unless workflow['concurrency']['group'] == group
  raise "Unprotected release: #{file}" unless workflow['concurrency']['cancel-in-progress'] == cancel
  triggers = workflow['on'] || workflow[true] # YAML 1.1 interprets 'on' as true.
  if triggers.key?('push')
    raise "Duplicate feature push validation: #{file}" unless triggers['push']['branches'] == ['bleeding', 'master']
    unless File.basename(file).match?(/build-(linux-modular|modular-optional)\.yml/)
      raise "Lost tag publishing: #{file}" unless triggers['push']['tags'] == ['**']
    end
  end
end
YAML.load_file("#{root}/.github/actions/platform-artifacts/action.yml")
puts 'Workflow scheduling and composite YAML checks passed'
