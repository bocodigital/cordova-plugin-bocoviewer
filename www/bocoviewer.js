var exec = require('cordova/exec');

exports.ready = function(arg0, success, error) {
    exec(success, error, "bocoviewer", "ready", [arg0]);
};


exports.showMedia = function(arg0, success, error) {
    exec(success, error, "bocoviewer", "showMedia", [arg0]);
};
