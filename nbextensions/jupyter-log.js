// Jupyter Notebook extension that logs various cell data on user generated events

// Most of my code borrows heavily from:
// https://github.com/ipython-contrib/jupyter_contrib_nbextensions/blob/master/src/jupyter_contrib_nbextensions/nbextensions/execute_time/ExecuteTime.js

// define([...], function(...) {..}) syntax is needed for require.js

var loggingEnabled = false

define([
    'require',
    'jquery',
    'base/js/namespace',
    'base/js/events',
    'notebook/js/codecell'
], function (
    requirejs,
    $,
    Jupyter,
    events,
    codecell
) {
    function load_ipython_extension() {

        var logData = [] // list log file that eventually gets saved to disk

        // This function is executed when the bug button is clicked
        // Should ideally set everything up and bind all events/callbacks
        var logHandler = function () {

            loggingEnabled = !loggingEnabled

            if (!loggingEnabled) {
                $('.fa-bug').css('color', 'red')
                console.info('Logging disabled') // events will still fire but won't be saved
                type = 'logstop'
                
            } else {
                $('.fa-bug').css('color', 'green')
                console.info('Logging Extension Loaded');
                type = 'logstart'
            }

            logData.push({
                type: type,
                time: Date.now(),
                meta: {},
                data: get_cell_data_and_rebind()
            })

            function jQueryEventLogger(evt) {
                if (evt.type == 'mousedown' || evt.type == 'mouseup') {
                    meta = {x: evt.clientX,
                            y: evt.clientY}
                } else if (evt.type == 'keydown') {
                    meta = {key: evt.key,
                            code: evt.keyCode}
                }
                console.log(evt.type, meta)

                data = get_cell_data_and_rebind()

                logData.push({
                    type: evt.type,
                    time: Date.now(),
                    meta: meta,
                    data: data
                })
            }

            function get_cell_data_and_rebind() {
                data = []
                cells = Jupyter.notebook.get_cells() // gets all cell objects in notebook

                for (var i = 0; i < cells.length; i++) { // iterates through all cells

                    if (typeof cells[i] == "undefined") {
                        continue
                    }

                    var cell = cells[i];
                    var ce = cell.element;

                    // Bind jQuery events to a cell
                    $(ce).unbind()
                    $(ce).on("mousedown mouseup keydown", jQueryEventLogger);

                    input = cell.get_text()

                    if (typeof cell.output_area == "undefined") {
                        outputs = []
                    } else {
                        outputs = cell.output_area.outputs
                    }

                    if (outputs.length == 0) {
                        out = {}
                    } else {
                        out = []
                        for (var k = 0; k < outputs.length; k++) {
                            if (outputs[0].output_type == 'stream') {
                                out.push({type: 'success',
                                       text: outputs[0].text})
                            } else if (outputs[0].output_type == 'execute_result') {
                                out.push({type: 'success',
                                       text: outputs[0].data['text/plain']})
                            } else if (outputs[0].output_type == 'error') {
                                output_lines = outputs[0].traceback
                                text = ''
                                for (var j = 0; j < output_lines.length; j++) {
                                    line = output_lines[j]
                                    line = line.replace(/[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g, '');
                                    text += line + '\n'
                                }

                                out.push({type: 'error',
                                       error_name: outputs[0].ename,
                                       error_value: outputs[0].evalue,
                                       text: text})
                            }
                        }
                    }

                    data.push({
                        id: cell.cell_id,
                        type: cell.cell_type,
                        in: input,
                        out: out
                    })
                }

                console.log(data)
                return data
            }

            get_cell_data_and_rebind()

            tracked_events = ['create.Cell',
                              'delete.Cell',
                              'execute.CodeCell',
                              'kernel_killed.Kernel',
                              'kernel_restarting.Kernel',
                              'notebook_saved.Notebook',
                              'rendered.MarkdownCell',
                              'select.Cell'];


            events.on(tracked_events.join(' '), jupyterEventLogger);

            // This function handles every Jupyter event (not jQuery)
            function jupyterEventLogger(evt, data) {
                if (evt.type == 'select' || evt.type == 'execute' || evt.type == 'rendered') {
                    meta = {id: data.cell.cell_id}
                } else if (evt.type == 'create' || evt.type == 'delete') {
                    meta = {id: data.cell.cell_id,
                            index: data.index}
                } else {
                    meta = {}
                }

                console.log(evt.type, meta)
                cell_data = get_cell_data_and_rebind()

                logData.push({
                  time: Date.now(),
                  type: evt.type,
                  meta: meta,
                  data: cell_data
                })                
            }
        };

        // Defines log button
        var log_action = {
            icon: 'fa-bug', // a font-awesome class used on buttons, https://fontawesome.com/icons
            help    : 'Log Jupyter Actions',
            help_index : 'z',
            handler : logHandler
        };
        var prefix = 'a';
        var log_action_name = 'log-data';

        // Binds action to button and adds button to toolbar
        var full_log_action_name = Jupyter.actions.register(log_action, log_action_name, prefix); // returns 'my_extension:show-alert'
        Jupyter.toolbar.add_buttons_group([full_log_action_name]);

        var getUserId = function() {
            cells = Jupyter.notebook.get_cells()
            uid = cells[0].get_text()
            return uid
        }


        // Function that is called when save button is pressed
        var saveLog = function () {
            console.log(logData)
            console.log(logData[0])

            if (logData.length == 0) {
                alert('Empty log, cancelling save')
                return
            }

            var uid = getUserId()
            var data = JSON.stringify(logData, null, 4) // converts JSON to string
            var blob = new File([data], {type: "application/json;charset=utf-8"});
            var timestamp = Date.now().toString()
            saveAs(blob, "log_" + uid + "_" + timestamp + ".json");
        };

        // Defines save button
        var save_action = {
            icon: 'fa-save', // we should probably use a different icon – already in use
            help    : 'Save Jupyter logs',
            help_index : 'zz',
            handler : saveLog
        };
        var prefix = 'b';
        var save_action_name = 'log-data';

        // Binds action to button and adds button to toolbar
        var full_save_action_name = Jupyter.actions.register(save_action, save_action_name, prefix); // returns 'my_extension:show-alert'
        Jupyter.toolbar.add_buttons_group([full_save_action_name]);
    }

    return {
        load_ipython_extension: load_ipython_extension
    };
});

// TODO: how to include/require FileSaver.js without copy-paste
// source: https://github.com/eligrey/FileSaver.js/blob/master/src/FileSaver.js

var saveAs = saveAs || (function(view) {
    "use strict";
    // IE <10 is explicitly unsupported
    if (typeof view === "undefined" || typeof navigator !== "undefined" && /MSIE [1-9]\./.test(navigator.userAgent)) {
        return;
    }
    var
          doc = view.document
          // only get URL when necessary in case Blob.js hasn't overridden it yet
        , get_URL = function() {
            return view.URL || view.webkitURL || view;
        }
        , save_link = doc.createElementNS("http://www.w3.org/1999/xhtml", "a")
        , can_use_save_link = "download" in save_link
        , click = function(node) {
            var event = new MouseEvent("click");
            node.dispatchEvent(event);
        }
        , is_safari = /constructor/i.test(view.HTMLElement) || view.safari
        , is_chrome_ios =/CriOS\/[\d]+/.test(navigator.userAgent)
        , setImmediate = view.setImmediate || view.setTimeout
        , throw_outside = function(ex) {
            setImmediate(function() {
                throw ex;
            }, 0);
        }
        , force_saveable_type = "application/octet-stream"
        // the Blob API is fundamentally broken as there is no "downloadfinished" event to subscribe to
        , arbitrary_revoke_timeout = 1000 * 40 // in ms
        , revoke = function(file) {
            var revoker = function() {
                if (typeof file === "string") { // file is an object URL
                    get_URL().revokeObjectURL(file);
                } else { // file is a File
                    file.remove();
                }
            };
            setTimeout(revoker, arbitrary_revoke_timeout);
        }
        , dispatch = function(filesaver, event_types, event) {
            event_types = [].concat(event_types);
            var i = event_types.length;
            while (i--) {
                var listener = filesaver["on" + event_types[i]];
                if (typeof listener === "function") {
                    try {
                        listener.call(filesaver, event || filesaver);
                    } catch (ex) {
                        throw_outside(ex);
                    }
                }
            }
        }
        , auto_bom = function(blob) {
            // prepend BOM for UTF-8 XML and text/* types (including HTML)
            // note: your browser will automatically convert UTF-16 U+FEFF to EF BB BF
            if (/^\s*(?:text\/\S*|application\/xml|\S*\/\S*\+xml)\s*;.*charset\s*=\s*utf-8/i.test(blob.type)) {
                return new Blob([String.fromCharCode(0xFEFF), blob], {type: blob.type});
            }
            return blob;
        }
        , FileSaver = function(blob, name, no_auto_bom) {
            if (!no_auto_bom) {
                blob = auto_bom(blob);
            }
            // First try a.download, then web filesystem, then object URLs
            var
                  filesaver = this
                , type = blob.type
                , force = type === force_saveable_type
                , object_url
                , dispatch_all = function() {
                    dispatch(filesaver, "writestart progress write writeend".split(" "));
                }
                // on any filesys errors revert to saving with object URLs
                , fs_error = function() {
                    if ((is_chrome_ios || (force && is_safari)) && view.FileReader) {
                        // Safari doesn't allow downloading of blob urls
                        var reader = new FileReader();
                        reader.onloadend = function() {
                            var url = is_chrome_ios ? reader.result : reader.result.replace(/^data:[^;]*;/, 'data:attachment/file;');
                            var popup = view.open(url, '_blank');
                            if(!popup) view.location.href = url;
                            url=undefined; // release reference before dispatching
                            filesaver.readyState = filesaver.DONE;
                            dispatch_all();
                        };
                        reader.readAsDataURL(blob);
                        filesaver.readyState = filesaver.INIT;
                        return;
                    }
                    // don't create more object URLs than needed
                    if (!object_url) {
                        object_url = get_URL().createObjectURL(blob);
                    }
                    if (force) {
                        view.location.href = object_url;
                    } else {
                        var opened = view.open(object_url, "_blank");
                        if (!opened) {
                            // Apple does not allow window.open, see https://developer.apple.com/library/safari/documentation/Tools/Conceptual/SafariExtensionGuide/WorkingwithWindowsandTabs/WorkingwithWindowsandTabs.html
                            view.location.href = object_url;
                        }
                    }
                    filesaver.readyState = filesaver.DONE;
                    dispatch_all();
                    revoke(object_url);
                }
            ;
            filesaver.readyState = filesaver.INIT;

            if (can_use_save_link) {
                object_url = get_URL().createObjectURL(blob);
                setImmediate(function() {
                    save_link.href = object_url;
                    save_link.download = name;
                    click(save_link);
                    dispatch_all();
                    revoke(object_url);
                    filesaver.readyState = filesaver.DONE;
                }, 0);
                return;
            }

            fs_error();
        }
        , FS_proto = FileSaver.prototype
        , saveAs = function(blob, name, no_auto_bom) {
            return new FileSaver(blob, name || blob.name || "download", no_auto_bom);
        }
    ;

    // IE 10+ (native saveAs)
    if (typeof navigator !== "undefined" && navigator.msSaveOrOpenBlob) {
        return function(blob, name, no_auto_bom) {
            name = name || blob.name || "download";

            if (!no_auto_bom) {
                blob = auto_bom(blob);
            }
            return navigator.msSaveOrOpenBlob(blob, name);
        };
    }

    // todo: detect chrome extensions & packaged apps
    //save_link.target = "_blank";

    FS_proto.abort = function(){};
    FS_proto.readyState = FS_proto.INIT = 0;
    FS_proto.WRITING = 1;
    FS_proto.DONE = 2;

    FS_proto.error =
    FS_proto.onwritestart =
    FS_proto.onprogress =
    FS_proto.onwrite =
    FS_proto.onabort =
    FS_proto.onerror =
    FS_proto.onwriteend =
        null;

    return saveAs;
}(
       typeof self !== "undefined" && self
    || typeof window !== "undefined" && window
    || this
));