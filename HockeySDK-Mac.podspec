Pod::Spec.new do |s|
  s.name              = 'HockeySDK-Mac'
  s.version           = '4.1.0-alpha.1'

  s.summary           = 'Collect live crash reports, get feedback from your users, distribute your betas, and get usage data.'
  s.description       = <<-DESC
                        HockeyApp is a service to distribute beta apps, collect crash reports and
                        communicate with your app's users.
                        
                        It improves the testing process dramatically and can be used for both beta
                        and App Store builds.
                        DESC

  s.homepage          = 'http://www.hockeyapp.net/'
  s.documentation_url = 'http://www.hockeyapp.net/help/sdk/mac/#{s.version}/'

  s.license           = { :type => 'MIT', :file => 'HockeySDK-Mac/LICENSE.txt' }
  s.author            = { 'Microsoft' => 'support@hockeyapp.net' }
  s.source = { :http => "https://download.hockeyapp.net/preseason/sdk/osx/HockeySDK-Mac-#{s.version}.zip",
               :sha1 => '2cc698fc1eef0212c0be238bc9e45a52dc8c835c' }

  s.platform              = :osx, '10.7'
  s.osx.deployment_target = 10.7
  s.requires_arc          = false
  
  s.vendored_frameworks   = "HockeySDK-Mac/HockeySDK.framework"
  s.public_header_files   = "HockeySDK-Mac/HockeySDK.framework/Versions/A/Headers/*.h*"
  s.resource              = "HockeySDK-Mac/HockeySDK.framework"
  s.xcconfig              = { 'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/../Frameworks' }

end