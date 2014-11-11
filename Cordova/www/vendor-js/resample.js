// http://webreflection.blogspot.com/2010/12/100-client-side-image-resizing.html
var Resample = (function () {

  // (C) WebReflection Mit Style License

  // modified by Michael lin 
  // added constructor, 
  // usage: new Resample().resample(img or dataURL, width, height, deferred(dataURL) )
  function Resample(canvas) {
    this.canvas = canvas || document.createElement("canvas");
    this.working = false;
  }

  function round(f) {
      return (0.5 + f) << 0;
  }

  // Resample function, accepts an image
  // as url, base64 string, or Image/HTMLImgElement
  // optional width or height, and a callback
  // to invoke on operation complete

  // 
  //  WARNING: Resample.resample() does NOT auto-rotate image
  //    this is an issue in HTML5 mode (with multi-select)
  //    CordovaCameraRoll uses navigator.camera.getPicture() to auto-rotate
  // 

  Resample.prototype.resample = function(img, width, height, deferred, mimeType) {
    var
      // check the image type
      load = typeof img == "string",
      // Image pointer
      i = load || img,

      self = this
    ;

    // manage state to allow reuse through Resample.one()
    if (self.working===true) throw "Error: Resample instance is still working" 
    self.working = true;

    // if string, a new Image is needed
    if (load) {
      i = new Image;
      // with propers callbacks
      i.onload = function(){
        Resample.onload.call(self, i, deferred)
      }
      i.onerror = function(){
        Resample.onerror.call(self, i, deferred)
      }
    }
    // easy/cheap way to store info
    i._deferred = deferred;
    i._width = width;
    i._height = height;
    i._mimeType = mimeType || "image/jpeg";
    // if string, we trust the onload event
    // otherwise we call onload directly
    // with the image as callback context
    load ? (i.src = img) : Resample.onload.call(this, img, deferred);
  }

  Resample.one = function(){
    var found = false;
        if (!Resample._instances) {
          Resample._instances = [];
        }
        for (var i =0; i<Resample._instances.length; i++ ) {
          if (Resample._instances[i] && Resample._instances[i].working === false) {
            found = Resample._instances[i]
            break;
          }
      }
        if (!found) {
          found = new Resample();
          Resample._instances.push(found);
        }
        return found;
  }
  
  // just in case something goes wrong
  Resample.onerror = function(img, deferred) {
    // throw ("not found: " + img.src);
    deferred.reject({ name: 'NotFound', src: img.src })
    this.working = false;

  }
  
  // called when the Image is ready
  Resample.onload = function(origImage, deferred) {
    var
      // minifier friendly
      img = origImage,
      // the desired width, if any
      width = img._width,
      // the desired height, if any
      height = img._height,
      // the callback
      callback = img._deferred, // callback

      mimeType = img._mimeType  // default = "image/jpeg"
    ;
    var canvas = this.canvas;
    var context = canvas.getContext("2d");
    // if width and height are both specified
    // the resample uses these pixels
    // if width is specified but not the height
    // the resample respects proportions
    // accordingly with orginal size
    // same is if there is a height, but no width
    width == null && (width = round(img.width * height / img.height));
    height == null && (height = round(img.height * width / img.width));

    if (img.width <= width) {
      src = typeof img == "string" ? img : img.src
      isDataUrl = src.indexOf("data:")==0
      if (isDataUrl) return deferred.resolve(src)   // force dataUrl
    }
    
    // remove (hopefully) stored info
    delete img._onresample;
    delete img._width;
    delete img._height;
    delete img._mimeType
    // when we reassign a canvas size
    // this clears automatically
    // the size should be exactly the same
    // of the final image
    // so that toDataURL ctx method
    // will return the whole canvas as png
    // without empty spaces or lines
    canvas.width = width;
    canvas.height = height;
    // drawImage has different overloads
    // in this case we need the following one ...

    context.drawImage(
      // original image
      img,
      // starting x point
      0,
      // starting y point
      0,
      // image width
      img.width,
      // image height
      img.height,
      // destination x point
      0,
      // destination y point
      0,
      // destination width
      width,
      // destination height
      height 
    );
    msg = "*** Resample.js: context.drawImage params=" + JSON.stringify([
      0,0,
      img.width,img.height,
      0,0,
      width,height 
      ]);
    console.log(msg)
    
    // retrieve the canvas content as
    // base4 encoded image
    try { 
      dataURL = canvas.toDataURL(mimeType);
      this.working = false
      deferred.resolve(dataURL);
    } catch (ex) {
      this.working = false
      switch (ex.name) {
        case 'SecurityError':  // CORS error
          err = {
            name: ex.name,
            src: img.src
          };
          break;
        default:
          throw ex;
      }
      deferred.reject(err)
    }

  }
  
  
  return Resample;
  
}()
);