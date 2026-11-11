require 'xcodeproj'

proj = Xcodeproj::Project.open(File.join(__dir__, 'App/App.xcodeproj'))
exit 0 if proj.targets.any? { |t| t.name == 'TrainLive' }

app = proj.targets.find { |t| t.name == 'App' }
app_group = proj.main_group.children.find { |g| g.respond_to?(:path) && g.path == 'App' }

app.build_configurations.each { |c| c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.2' }
proj.build_configurations.each { |c| c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.2' }

refs = %w[MainViewController.swift TrainNativePlugin.swift TrainActivityAttributes.swift].map { |f| app_group.new_reference(f) }
app.add_file_references(refs)
app.add_resources([app_group.new_reference('rest.wav')])

ext = proj.new_target(:app_extension, 'TrainLive', :ios, '16.2', nil, :swift)
grp = proj.main_group.new_group('TrainLive', 'TrainLive')
ext.add_file_references(%w[TrainLiveBundle.swift TrainLiveActivity.swift TrainHomeWidget.swift].map { |f| grp.new_reference(f) })
grp.new_reference('Info.plist')
grp.new_reference('TrainLive.entitlements')
app_group.new_reference('App.entitlements')
app.build_configurations.each { |c| c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'App/App.entitlements' }
ext.add_file_references([refs.last])
%w[WidgetKit SwiftUI ActivityKit].each { |fw| ext.add_system_framework(fw) }

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.j7331.train.TrainLive'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'TrainLive/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '16.2'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['CODE_SIGN_ENTITLEMENTS'] = 'TrainLive/TrainLive.entitlements'
end

embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
app.add_dependency(ext)

proj.save
puts 'Live Activity extension added'
