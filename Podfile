use_frameworks!

def shared_pods
    pod 'CoreGPX'
end

target 'OpenGpxTracker' do
    platform :ios, '9.0'
    shared_pods
    pod 'MapCache', '~> 0.9.0'
    #pod 'MapCache', git: 'https://github.com/merlos/MapCache.git' :branch => 'master'
    
end

target 'OpenGpxTracker-Watch Extension' do
    platform :watchos, '2.0'
    shared_pods
end
