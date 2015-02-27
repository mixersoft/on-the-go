var gulp = require('gulp');
var gutil = require('gulp-util');
var bower = require('bower');
var concat = require('gulp-concat');
var sass = require('gulp-sass');
var minifyCss = require('gulp-minify-css');
var rename = require('gulp-rename');
var sh = require('shelljs');
var shell = require('gulp-shell')
var del = require('del');


var paths = {
  sass: ['./scss/**/*.scss'],
  coffee: ['./app/scripts/**/*.coffee'],
  views: ['./app/views/**/*.html'],
  legal: ['./app/legal/**/*.html'],
  build: ['./dist/**/*', '!./dist/components/**'],
  jsDev: ['./www/js/**/*.js', '!./www/js/**/*.min.js', '!templates.js'],
  html2js: ['./www/views/partials/**/*.html']
};

gulp.task('default', ['sass', 'coffee', 'copy:html']);
gulp.task('build', ['unbuild', 'grunt:build', 'copy:build', 'clean:dev'])
gulp.task('unbuild', ['clean', 'copy:more', 'default'])

gulp.task('sass', function(done) {
  gulp.src(paths.sass)
    .pipe(sass())
    .pipe(gulp.dest('./www/css/'))
    .pipe(minifyCss({
      keepSpecialComments: 0
    }))
    .pipe(rename({ extname: '.min.css' }))
    .pipe(gulp.dest('./www/css/'))
    .on('end', done);
});

gulp.task('watch', function() {
  gulp.watch(paths.sass, ['sass'])
  gulp.watch(paths.coffee, ['coffee']);
  gulp.watch(paths.views, ['copy:html']);
});

gulp.task('install', ['git-check'], function() {
  return bower.commands.install()
    .on('log', function(data) {
      gutil.log('bower', gutil.colors.cyan(data.id), data.message);
    });
});

gulp.task('git-check', function(done) {
  if (!sh.which('git')) {
    console.log(
      '  ' + gutil.colors.red('Git is not installed.'),
      '\n  Git, the version control system, is required to download Ionic.',
      '\n  Download git here:', gutil.colors.cyan('http://git-scm.com/downloads') + '.',
      '\n  Once git is installed, run \'' + gutil.colors.cyan('gulp install') + '\' again.'
    );
    process.exit(1);
  }
  done();
});


// added 
var coffee = require('gulp-coffee');
gulp.task('coffee', function() {
  gulp.src(paths.coffee)
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(gulp.dest('./www/js/'))
});

gulp.task('copy:html', function(){
  gulp.src(paths.views)
    .pipe(gulp.dest('./www/views/'));
})

gulp.task('clean', function(cb) {
  // You can use multiple globbing patterns as you would with `gulp.src`
  del(['dist', '.tmp','./www/js/*.min.js', ], cb);
});

gulp.task('copy:more', function(){
  gulp.src(paths.legal)
    .pipe(gulp.dest('./www/legal/'));
  gulp.src('./app/index.html')
    .pipe(gulp.dest('./www/'));
})



gulp.task('grunt:build', ['unbuild'], function(cb){
  return gulp.src('')
    .pipe(
      shell([
      'grunt build'
      ])
    )
});


gulp.task('copy:build', ['grunt:build'], function(cb){
  return gulp.src(paths.build)
    .pipe(gulp.dest('./www/'));
})



gulp.task('clean:dev', ['copy:build'], function(cb){
    del(paths.jsDev)
    del(paths.html2js)
    cb()
})
