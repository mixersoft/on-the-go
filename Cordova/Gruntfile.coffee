module.exports = (grunt)->

  # Run 'grunt' for steroids connect
  grunt.registerTask("build", [
      "copy", 
      "optimize"    
  ]);

  grunt.registerTask("unbuild", [
      'copy:optimize'    
  ]);
  
  # Optimize pre-built, web-accessible resources for production, primarily `usemin`
  # run after `grunt server`
  # grunt.registerTask('optimize', [ 'copy:fonts', 'useminPrepare', 'concat', 'uglify', 'cssmin', 'rev', 'usemin', 'express', 'watch' ])
  # grunt.registerTask('optimize', [ 'copy:fonts', 'useminPrepare', 'concat', 'uglify', 'cssmin', 'rev', 'usemin', 'watch' ])
  grunt.registerTask('optimize', [ 
    'copy:optimize'
    'useminPrepare'
    'html2js'
    'concat'
    'uglify'
    'cssmin'
    'usemin'
  ])


  # Configuration
  grunt.config.init

    # Directory CONSTANTS
    BUILD_DIR:      'dist/'
    WWW_DIR:        'www/'
    APP_DIR:        'app/'
    COMPONENTS_DIR: 'www/components/'

    # Glob CONSTANTS
    ALL_FILES:      '**/*'
    ION_FILES:      '**/lib/ionic/**'
    CSS_FILES:      '**/*.css'
    HTML_FILES:     '**/*.html'
    IMG_FILES:      '**/*.{png,gif,jpg,jpeg}'
    JS_FILES:       '**/*.js'
    SASS_FILES:     '**/*.scss'
    LESS_FILES:     '**/*.less'
    FONT_FILES:     '**/font'
    DATA_FILES:     '**/*.json'



    copy:
      optimize:
        src:'<%= APP_DIR %>/index.html'
        dest:'<%= BUILD_DIR %>/index.html'
      #
      # App images from Bower `components` & `client`
      images:
        files:      [
          expand:   true
          cwd:      '<%= WWW_DIR %>'
          src:      ['<%= IMG_FILES %>', '!**/components/**', '!**/lib/**']
          dest:     '<%= BUILD_DIR %>'
        ]

      # data:
      #   files:      [
      #     expand:   true
      #     cwd:      '<%= APP_DIR %>'
      #     src:      ['**/data/<%= DATA_FILES %>', '!**/components/**', '!**/lib/**']
      #     dest:     '<%= BUILD_DIR %>'
      #   ]
      # ionic:
      #   files:      [
      #     expand:   true
      #     cwd:      '<%= WWW_DIR %>'
      #     src:      ['<%= ION_FILES %>', '!**/scss/**']
      #     dest:     '<%= BUILD_DIR %>'
      #   ]        
      js:
        files:      [
          expand:   true
          cwd:      '<%= WWW_DIR %>'
          src:      ['<%= JS_FILES %>', '!**/components/**', '!**/lib/**', '!**/fonts/**']
          dest:     '<%= BUILD_DIR %>'
        ,
          expand:   true
          cwd:      '<%= WWW_DIR %>'
          src:      '<%= ION_FILES %><%= JS_FILES %>'
          dest:     '<%= BUILD_DIR %>'        
        , 
          expand:   true
          cwd:      '<%= WWW_DIR %>components/'
          src:      ['<%= JS_FILES %>', '!**/examples/**', '!**/src/**', '!**/test/**']
          dest:     '<%= BUILD_DIR %>components/'        
        ]
      css:
        files:      [
          expand:   true
          cwd:      '<%= WWW_DIR %>'
          src:      ['components/angular-native-picker/<%= CSS_FILES %>']
          dest:     '<%= BUILD_DIR %>'
        ,
          expand:   true
          cwd:      '<%= WWW_DIR %>'
          src:      ['<%= CSS_FILES %>', '!**/components/**', '!**/lib/**']
          dest:     '<%= BUILD_DIR %>'
        ]
      fonts:
        files:      [
          expand:   true
          cwd:      '<%= WWW_DIR %>'
          src:      ['**/fonts/*', '!**/components/**', '!**/lib/**']
          dest:     '<%= BUILD_DIR %>fonts/'
          flatten:  false
          filter:   'isFile'
          
        , # for ionicons v2.0 fonts 
          expand:   true
          cwd:      '<%= WWW_DIR %>components/'
          src:      ['ionicons/fonts/**']
          dest:     '<%= BUILD_DIR %>components/'
          flatten:  false
          filter:   'isFile'          

        , # for snappi fonts 
          expand:   true
          cwd:      '<%= WWW_DIR %>vendor/fonts/'
          src:      ['Roboto/*','HomemadeApple/*','GeoSansLight/*','SourceSansPro/*']
          dest:     '<%= BUILD_DIR %>fonts/'
          flatten:  false
          filter:   'isFile'

        ]  

          # app (non-Bower) HTML in `client`
      html:     # WARING: overwrites results from steroids-compile-views
        files:      [
          expand:   true
          cwd:      '<%= WWW_DIR %>'
          src:      ['<%= HTML_FILES %>', '!**/vendor/**', '!**/components/**']
          dest:     '<%= BUILD_DIR %>'
        ]

      usemin:
        XXXfiles: [
          expand: true
          cwd: '.tmp/concat/'
          src: '<%= ALL_FILES %>'
          dest: '<%= BUILD_DIR %>'
        ]

    # Ability to run `jshint` without errors terminating the development server
    parallel:
      less:         [ grunt: true, args: [ 'less' ] ]
      jshint:       [ grunt: true, args: [ 'jshint' ] ]
      # compass:      [ grunt: true, args: [ 'compass' ] ]


    # Validate app `client` and `server` JS
    jshint:
      files:        [
                    '<%= WWW_DIR + "js/" + JS_FILES %>'
                    '<%= WWW_DIR + "vendor-js/" + JS_FILES %>'
                    ]
      options:
        es5:        true
        laxcomma:   true  # Common in Express-derived libraries


    # Browser-based testing
    # Minify app `.css` resources -> `.min.css`
    cssmin: 
      minify: 
        expand: true,
        cwd: '<%= BUILD_DIR %>css',
        src: ['*.css', '!*.min.css'],
        dest: '<%= BUILD_DIR %>css',
        ext: '.min.css'

    # Prepend a hash on file names for versioning
    rev:
      files:
        src:  ['<%= BUILD_DIR %>/app/scripts/all.min.js','<%= BUILD_DIR %>/app/styles/app.min.css']

    # Output for optimized app index
    usemin:
      html:         '<%= BUILD_DIR %>index.html'



    # Input for optimized app index
    useminPrepare:
      html:         '<%= BUILD_DIR %>index.html'
      options: 
        flow: 
          steps: 
            # js: [uglifyNew, 'concat']
            # css: ['cssmin']
            js: ['concat', 'uglifyjs']
            css: ['cssmin']
          post: []

    uglify:
      options:
        mangle:
          except: ['**/*.min.js']


    html2js: {
      options:
        base: 'app',
        module: 'onthego.templates',
        singleModule: true,
        useStrict: true,
        htmlmin: {
          collapseBooleanAttributes: true,
          collapseWhitespace: true,
          removeAttributeQuotes: true,
          removeComments: true,
          removeEmptyAttributes: true,
          removeRedundantAttributes: false,
          removeScriptTypeAttributes: true,
          removeStyleLinkTypeAttributes: true
        }  
      main:
        src:['<%= APP_DIR %>views/partials/<%= HTML_FILES %>']
        dest: '<%= WWW_DIR %>js/templates.js'      
    }



  grunt.loadNpmTasks('grunt-contrib-copy')
  grunt.loadNpmTasks('grunt-contrib-jshint')
  grunt.loadNpmTasks('grunt-contrib-cssmin')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-concat')
  grunt.loadNpmTasks('grunt-usemin')
  grunt.loadNpmTasks('grunt-rev')
  grunt.loadNpmTasks('grunt-html2js')



