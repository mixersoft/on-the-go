
/* 
 * On-the-Go project config
 */
sudo npm install -g bower ionic 
ionic start snappi-onthego; cd snappi-onthego;
ionic platform ios

ionic plugin add org.apache.cordova.console 
ionic plugin add org.apache.cordova.device 
ionic plugin add org.apache.cordova.file
ionic plugin add com.ionic.keyboard 
ionic plugin add me.apla.cordova.app-preferences 

git clone https://github.com/mixersoft/on-the-go.git git_temp
cp -rf ./git_temp/* .
rm -rf ./git_temp

# dependencies
npm install
bower install 

# build
gulp
ionic build ios
