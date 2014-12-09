###
### On-the-Go:  Project Config
###
  

### install node/nvm if not available. for OSX, see:
###   - https://github.com/creationix/nvm
# curl https://raw.githubusercontent.com/creationix/nvm/v0.18.0/install.sh | bash
# nvm install stable


### required node packages, install globally:
npm install -g bower gulp cordova ionic
### optional: packages for angular development
# npm install -g grunt-cli yo generator-angular generator-angular-bootstrap generator-karma   


### clone the github repo
#echo 'enter github user credentials'
#git clone https://github.com/mixersoft/on-the-go.git snappi-onthego
###
### prompt> provide github user/pass
###

### goto cordova project folder
#cd snappi-onthego/Cordova


### install dependencies
echo '{
  "directory": "bower_components"
}' > .bowerrc
### OR, add .bowerrc to github repo

bowerComponentsDir=/bower_components
if [ ! -d "$bowerComponentsDir"]; then
    mkdir $bowerComponentsDir
fi

npm install
npm list gulp-sass
echo 'confirm gulp-sass was correctly installed, may need sudo'
### NOTE: confirm correct install of gulp-sass, type `npm list gulp-sass`  
### it may need to be installed as administrator
# sudo npm install gulp-sass

bower install 
unlink ./www/components
ln -s ../bower_components ./www/components



### install Cordova platform for ios and plugins
ionic platform ios
ionic plugin add org.apache.cordova.console 
ionic plugin add org.apache.cordova.device
ionic plugin add org.apache.cordova.file
ionic plugin add com.ionic.keyboard 
ionic plugin add me.apla.cordova.app-preferences 
ionic plugin add https://github.com/EddyVerbruggen/SocialSharing-PhoneGap-Plugin.git
#ionic plugin rm com.snaphappi.native-messenger.Messenger
ionic plugin add ../CordovaNativeMessenger
# ionic plugin add org.apache.cordova.file-transfer


### install ionic libs to ./www/lib
echo 'answer "yes" to install ionic libs to cordova project'
ionic lib update
###
### prompt> answer 'yes'
###

###
### On-the-Go: Project Build
###     Once the project has been successfully configured, 
###     just run this build step
###
gulp; ionic build ios;

### run, or open ./platforms/ios/ion-OnTheGo.xcodeproj
#ionic emulate