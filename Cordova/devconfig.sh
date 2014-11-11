

#
# On-the-Go project config
#
sudo npm install -g bower ionic gulp


#git clone https://github.com/mixersoft/on-the-go.git snappi-onthego
#
# provide github user/pass
#


#cd snappi-onthego;
ionic lib update
#
# answer 'yes'
#

ln -s /bower_components ./www/components
ionic platform ios
ionic plugin add org.apache.cordova.console 
ionic plugin add org.apache.cordova.device 
ionic plugin add org.apache.cordova.file
ionic plugin add com.ionic.keyboard 
ionic plugin add me.apla.cordova.app-preferences 
# install dependencies
npm install
bower install 

# build
gulp
ionic build ios

# run, or open ./platforms/ios/ion-OnTheGo.xcodeproj
#ionic emulate