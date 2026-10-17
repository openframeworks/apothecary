require 'yaml'

root = File.expand_path('../..', __dir__)
group = "${{ github.workflow }}-${{ startsWith(github.ref, 'refs/tags/') && github.run_id || github.event.pull_request.number || github.ref }}"
release_tags = ['**', '!latest', '!latest-modular', '!nightly', '!build-state', '!nightly-staging-*', '!nightly-previous-*']
cancel = "${{ !startsWith(github.ref, 'refs/tags/') }}"
Dir["#{root}/.github/workflows/build*.yml"].each do |file|
  workflow = YAML.load_file(file)
  next unless workflow['concurrency']
  raise "Unstable group: #{file}" unless workflow['concurrency']['group'] == group
  raise "Unprotected release: #{file}" unless workflow['concurrency']['cancel-in-progress'] == cancel
  triggers = workflow['on'] || workflow[true] # YAML 1.1 interprets 'on' as true.
  if triggers.key?('push')
    raise "Duplicate feature push validation: #{file}" unless triggers['push']['branches'] == ['bleeding', 'master']
    unless File.basename(file).match?(/build-(linux(?:-[a-z0-9]+)?-modular|modular-optional)\.yml/)
      raise "Lost tag publishing: #{file}" unless triggers['push']['tags'] == release_tags
    end
  end
end
# GitHub evaluates positive/negative patterns in order; metadata never compiles.
match_tag = lambda do |tag|
  selected = false
  release_tags.each do |pattern|
    negative = pattern.start_with?('!')
    glob = negative ? pattern[1..-1] : pattern
    selected = !negative if File.fnmatch?(glob, tag)
  end
  selected
end
['v12.2.0', '12.2.0', 'v13.0.0-rc1'].each { |tag| raise "Lost version tag #{tag}" unless match_tag.call(tag) }
['latest', 'latest-modular', 'nightly', 'build-state', 'nightly-staging-123-1', 'nightly-previous-123-1'].each do |tag|
  raise "Metadata tag starts builds: #{tag}" if match_tag.call(tag)
end
YAML.load_file("#{root}/.github/actions/platform-artifacts/action.yml")
puts 'Workflow scheduling and composite YAML checks passed'
