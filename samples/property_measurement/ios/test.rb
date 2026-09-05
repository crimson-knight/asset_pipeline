#!/usr/bin/env ruby
# Real, isolated simulator gate. No customer app, backend or provider writes.
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require 'tmpdir'
require 'timeout'

options = {}
OptionParser.new do |parser|
  parser.banner = 'ruby samples/property_measurement/ios/test.rb --simulator UUID --native-deps DIR [--output NEW_DIR]'
  parser.on('--simulator UUID') { |v| options[:simulator] = v }
  parser.on('--native-deps DIR') { |v| options[:deps] = File.expand_path(v) }
  parser.on('--output NEW_DIR') { |v| options[:output] = File.expand_path(v) }
end.parse!
abort 'An explicit dedicated simulator UUID is required; never use the booted alias.' unless options[:simulator]&.match?(/\A[0-9a-f-]{36}\z/i)
abort 'Supply the existing simulator C-library directory.' unless options[:deps] && %w[libgc.a libpcre2-8.a].all? { |file| File.file?(File.join(options[:deps], file)) }

repo = File.expand_path('../../..', __dir__)
capture = lambda do |*args|
  stdout, stderr, status = Open3.capture3(*args, chdir: repo)
  raise "#{args.first} failed: #{stderr.strip}" unless status.success?
  stdout
end
devices = JSON.parse(capture.call('xcrun', 'simctl', 'list', 'devices', '--json')).fetch('devices')
selected = devices.select { |runtime, _| runtime.include?('.iOS-') }.values.flatten.find { |device| device['udid'] == options[:simulator] }
abort 'The selected iOS simulator must exist, be available and already booted; this gate does not change other simulator state.' unless selected && selected['isAvailable'] && selected['state'] == 'Booted'
if options[:output]
  abort 'Output must be a new directory; prior evidence will not be overwritten.' if File.exist?(options[:output])
  FileUtils.mkdir_p(options[:output])
else
  options[:output] = Dir.mktmpdir('ap-property-ui-')
end
output = options[:output]
puts "Property simulator evidence: #{output}"
run = lambda do |log_name, environment, *args|
  puts log_name
  File.open(File.join(output, log_name), 'w') do |log|
    pid = Process.spawn(environment, *args, chdir: repo, out: log, err: [:child, :out], pgroup: true)
    begin
      # XCTest's per-case timeout does not bound a stuck simulator launch RPC.
      # Bound our own driver as well, without restarting system-wide services.
      _, status = Timeout.timeout(900) { Process.wait2(pid) }
    rescue Timeout::Error
      begin
        Process.kill('TERM', -pid)
        Timeout.timeout(10) { Process.wait(pid) }
      rescue Timeout::Error
        Process.kill('KILL', -pid) rescue nil
        Process.wait(pid) rescue nil
      rescue Errno::ESRCH, Errno::ECHILD
        # It exited between the deadline and signal/reap.
      end
      raise "#{log_name} exceeded the 15-minute driver deadline; inspect the retained evidence and dedicated simulator."
    end
    outcome = status.signaled? ? "signal #{status.termsig}" : "exit #{status.exitstatus}"
    raise "#{log_name} failed (#{outcome}); retained log and result bundle are authoritative." unless status.success?
  end
end

receipt = { 'status' => 'running', 'started_at' => Time.now.utc.iso8601,
            'scope' => 'synthetic property fixture only; no backend, customer, geocoding, pricing or entitlement proof',
            'simulator' => selected, 'bundle_id' => 'com.assetpipeline.propertyfixture' }
begin
  receipt['git_head'] = capture.call('git', 'rev-parse', 'HEAD').strip
  receipt['git_status'] = capture.call('git', 'status', '--short')
  receipt['compiler'] = capture.call(ENV.fetch('CRYSTAL', 'crystal-alpha'), '--version').strip
  receipt['xcode'] = capture.call('xcodebuild', '-version').strip
  roots = %w[src swift/AssetPipelineSwiftKit/Sources samples/property_measurement/ios spec/geometry spec/web/ui spec/fixtures]
  sources = roots.flat_map { |root| Dir.glob(File.join(repo, root, '**', '*')) }.select { |path| File.file?(path) }
  sources.reject! { |path| path.include?('/build/') || path.include?('.xcodeproj/') }
  receipt['source_sha256'] = sources.sort.to_h { |path| [path.delete_prefix(repo + '/'), Digest::SHA256.file(path).hexdigest] }
  receipt['native_dependency_sha256'] = %w[libgc.a libpcre2-8.a].to_h { |file| [file, Digest::SHA256.file(File.join(options[:deps], file)).hexdigest] }
  # Finder/file-provider metadata in synced Documents can make otherwise valid
  # app bundles unsignable. Build code in a new task-private temporary directory;
  # retain human-readable logs, XCTest results and disk proof in the chosen
  # evidence directory. Do not strip metadata from user folders or SDK files.
  derived = Dir.mktmpdir('ap-property-derived-')
  receipt['derived_data'] = derived
  run.call('native-library-build.log', { 'CRYSTAL_CACHE_DIR' => File.join(derived, 'crystal-cache') }, 'bash', File.join(__dir__, 'build.sh'))
  run.call('xcode-build.log', {}, 'xcodebuild', 'build-for-testing', '-project', File.join(__dir__, 'PropertyMeasurementFixture.xcodeproj'),
           '-scheme', 'PropertyMeasurementFixture', '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', derived,
           "AP_NATIVE_DEPS_DIR=#{options[:deps]}", 'CODE_SIGNING_ALLOWED=NO')
  products = File.join(derived, 'Build', 'Products')
  app = File.join(products, 'Debug-iphonesimulator', 'PropertyMeasurementFixture.app')
  runner = File.join(products, 'Debug-iphonesimulator', 'PropertyMeasurementFixtureUITests-Runner.app')
  run.call('sign-app.log', {}, 'codesign', '--force', '--deep', '--sign', '-', '--timestamp=none', app)
  run.call('sign-tests.log', {}, 'codesign', '--force', '--deep', '--sign', '-', '--timestamp=none', runner)
  receipt['app_binary_sha256'] = Digest::SHA256.file(File.join(app, 'PropertyMeasurementFixture')).hexdigest
  # Debug Xcode builds may put executable code in an injection dylib.
  receipt['app_code_sha256'] = Dir.glob(File.join(app, '*')).select { |path| File.file?(path) && (File.basename(path) == 'PropertyMeasurementFixture' || path.end_with?('.dylib')) }.sort.to_h { |path| [File.basename(path), Digest::SHA256.file(path).hexdigest] }
  plans = Dir.glob(File.join(products, '*.xctestrun'))
  raise 'Expected exactly one generated XCTest plan.' unless plans.size == 1
  base = ['xcodebuild', 'test-without-building', '-xctestrun', plans.first,
          '-destination', "platform=iOS Simulator,id=#{options[:simulator]}", '-parallel-testing-enabled', 'NO',
          '-test-timeouts-enabled', 'YES', '-maximum-test-execution-time-allowance', '180']
  expected = File.read(File.join(__dir__, 'UITests', 'PropertyMeasurementTests.swift')).scan(/^\s*func (test\w+)\(/).size
  raise 'No native acceptance cases discovered.' if expected.zero?
  verify = lambda do |name, count, extra|
    result = File.join(output, "#{name}.xcresult")
    run.call("#{name}.log", {}, *base, '-resultBundlePath', result, *extra)
    summary = JSON.parse(capture.call('xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', result))
    File.write(File.join(output, "#{name}-summary.json"), JSON.pretty_generate(summary) + "\n")
    raise "#{name} did not pass every expected test with zero skips." unless summary['result'] == 'Passed' && summary['passedTests'] == count && summary['failedTests'] == 0 && summary['skippedTests'] == 0 && summary['expectedFailures'] == 0
    receipt[name] = { 'passed' => count, 'failed' => 0, 'skipped' => 0 }
  end
  verify.call('all-tests', expected, [])
  # Deliberately last, independent of XCTest order: other tests reset only this
  # synthetic installation, so a separate persistence run leaves real prefs to
  # inspect on disk. The test terminates/relaunches and compares the full JSON.
  verify.call('persistence', 1, ['-only-testing:PropertyMeasurementFixtureUITests/PropertyMeasurementTests/testDrawExcludeUndoSaveAndRestoreFromDisk'])
  container = capture.call('xcrun', 'simctl', 'get_app_container', options[:simulator], receipt['bundle_id'], 'data').strip
  preferences = JSON.parse(capture.call('plutil', '-convert', 'json', '-o', '-', File.join(container, 'Library', 'Preferences', receipt['bundle_id'] + '.plist')))
  outline = JSON.parse(preferences.fetch('saved-outline'))
  raise 'Saved simulator disk data is not a measured outline.' unless outline['schema'] == 'ap.property-outline.v1' && outline.fetch('ring_ids').size == 2 && outline.dig('measurement', 'net_area_m2').to_f > 0
  File.write(File.join(output, 'outline-from-simulator-disk.json'), JSON.pretty_generate(outline) + "\n")
  receipt['saved_outline_sha256'] = Digest::SHA256.hexdigest(preferences.fetch('saved-outline'))
  receipt['status'] = 'passed'
rescue StandardError => error
  receipt['status'] = 'failed'
  receipt['error'] = error.message
  warn error.message
ensure
  receipt['finished_at'] = Time.now.utc.iso8601
  File.write(File.join(output, 'receipt.json'), JSON.pretty_generate(receipt) + "\n")
end
exit(receipt['status'] == 'passed' ? 0 : 1)
