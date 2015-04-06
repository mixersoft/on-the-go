// (function(ionic) {

angular.module('ionic.ion.headerShrink', ['ionic'] )
.directive('headerShrink', function() {
  var fadeAmt;

  var shrink = function(header, content, amt, max) {
    amt = Math.min(max, amt);
    fadeAmt = 1 - amt / max;
    ionic.requestAnimationFrame(function() {
      header.style[ionic.CSS.TRANSFORM] = 'translate3d(0, -' + amt + 'px, 0)';
      for(var i = 0, j = header.children.length; i < j; i++) {
        header.children[i].style.opacity = fadeAmt;
      }
    });
  };

  return {
    restrict: 'A',
    link: function($scope, $element, $attr) {
      if ( $attr.platform && document.body.className.indexOf($attr.platform) == -1) {
        // check body for required platform, 'platform-browser' or 'platform-webview'
          return
      }
      var starty = $scope.$eval($attr.platform) || 0;
      var shrinkAmt;

      var amt;

      var y = 0;
      var prevY = 0;
      var scrollDelay = 0.4;

      var fadeAmt;
      
      // var header = $document[0].body.querySelector('.bar-header');
      // var headerHeight = header.offsetHeight;      
      var parent = ionic.DomUtil.getParentWithClass($element[0],'menu-content');
      var headers = parent.getElementsByClassName('bar-header');
      var headerHeight = headers[0].offsetHeight;
      
      function onScroll(e) {
        var scrollTop = e.detail.scrollTop;

        if(scrollTop >= 0) {
          y = Math.min(headerHeight / scrollDelay, Math.max(0, y + scrollTop - prevY));
        } else {
          y = 0;
        }
        // console.log(scrollTop);

        ionic.requestAnimationFrame(function() {
          fadeAmt = 1 - (y / headerHeight);
          // header.style[ionic.CSS.TRANSFORM] = 'translate3d(0, ' + -y + 'px, 0)';
          // for(var i = 0, j = header.children.length; i < j; i++) {
          //   header.children[i].style.opacity = fadeAmt;
          // }
          for (var h=0; h<headers.length; h++) {
            headers[h].style[ionic.CSS.TRANSFORM] = 'translate3d(0, ' + -y + 'px, 0)';
            for(var i = 0, j = headers[h].children.length; i < j; i++) {
              headers[h].children[i].style.opacity = fadeAmt;
            }
          }
          $element[0].style.top = Math.max(headerHeight-y, 0) + 'px'
        });

        prevY = scrollTop;
      }

      $element.bind('scroll', onScroll);
    }
  }
});

// })(window.ionic);


