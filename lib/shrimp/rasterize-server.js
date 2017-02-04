var
  webpage   = require('webpage'),
  fs        = require('fs'),
  system    = require('system'),
  args      = system.args,
  webserver = require('webserver'),
  listen_on = ('127.0.0.1:' + args[1]),
  server    = webserver.create();

function defaultOptions() {
  return {
    margin: '0cm',
    orientation: 'portrait',
    rendering_time: 500,
    time_out: 90000,
    viewport_width: 600,
    viewport_height: 600,
    redirects_num: 0,
    footer_size: '0cm',
    header_size: '0cm'
  };
};

function optionsFromURL(url) {
  var query = url.split('?')[1];
  var parsedParams = defaultOptions();

  query.split('&').forEach(function(param){
    var split = param.split('=');
    parsedParams[split[0]] = split[1];
  });

  var page_options = {
    viewportSize: {
      width:  parsedParams.viewport_width,
      height: parsedParams.viewport_height
    },

    paperSize: {
      format:      'Letter',
      orientation: parsedParams.orientation,
      margin: parsedParams.margin
    },
    rendering_time: parsedParams.rendering_time
  };

  if (parsedParams.zoom_factor) {
    page_options.zoomFactor = parsedParams.zoom_factor;
  }

  if (parsedParams.paper_width && parsedParams.paper_height) {
    page_options.paperSize = {
      width:  parsedParams.paper_width,
      height: parsedParams.paper_height,
      margin: '0px'
    };
  } else if (parsedParams.paper_format) {
    page_options.paperSize.format = parsedParams.paper_format;
  }

  if (parsedParams.header_file) {
    try {
      header = fs.open(parsedParams.header_file, "r");
      header_content = header.read();
      fs.remove(parsedParams.header_file);

      page_options.paperSize.header = {
        height: parsedParams.header_size,
        contents: phantom.callback(function() {
          return function(pageNum, numPages){
            return header_content.replace('{{total_pages}}', numPages).replace('{{current_page}}', pageNum);
          }
        }())
      };
    } catch (e) {
      console.log(e);
    }
  }

  if (parsedParams.footer_file) {
    try {
      footer = fs.open(parsedParams.footer_file, "r");
      footer_content = footer.read();
      fs.remove(parsedParams.footer_file);

      page_options.paperSize.footer = {
        height: parsedParams.footer_size,
        contents: phantom.callback(function() {
          return function(pageNum, numPages) {
            return footer_content.replace('{{total_pages}}', numPages).replace('{{current_page}}', pageNum);
          }
        }())
      };

    } catch (e) {
      console.log(e);
    }
  }
  page_options.in  = parsedParams['in'];
  page_options.out = parsedParams['out'];
  return page_options;
}

function renderUrl(url, output, options, callback) {
  options = options || {};

  var statusCode,
      page = webpage.create();
  for (var k in options) {
    if (options.hasOwnProperty(k)) {
      page[k] = options[k];
    }
  }

  // determine the statusCode
  page.onResourceReceived = function (resource) {
    if (resource.url == url) {
      statusCode = resource.status;
    }
  };

  page.onResourceError = function (resourceError) {
    error(resourceError.errorString + ' (URL: ' + resourceError.url + ')');
  };

  page.onNavigationRequested = function (redirect_url, type, willNavigate, main) {
    if (main) {
      if (redirect_url !== url) {
        page.close();

        if (redirects_num-- >= 0) {
          renderUrl(redirect_url, output, options);
        } else {
          error(url + ' redirects to ' + redirect_url + ' after maximum number of redirects reached');
        }
      }
    }
  };

  page.onCallback = function(data) {
    console.log(data);
  };

  page.open(url, function (status) {
    if (status !== 'success' || (statusCode != 200 && statusCode != null)) {
      if (fs.exists(output)) {
        fs.remove(output);
      }
      try {
        fs.touch(output);
      } catch (e) {
        console.log(e);
      }
      error('Unable to load the URL: ' + url + ' (HTTP ' + statusCode + ')');
    } else {
      window.setTimeout(function () {
        page.render(output + '_tmp.pdf');

        if (fs.exists(output)) {
          fs.remove(output);
        }

        try {
          fs.move(output + '_tmp.pdf', output);
        } catch (e) {
          error(e);
        }
        console.log('Rendered to: ' + output, new Date().getTime());
        callback('Rendered to: ' + output, new Date().getTime() + '\n');
        // phantom.exit(0);
      }, options.rendering_time);
    }
  });
}

service = server.listen(listen_on, function(request, response) {
  console.log('got request');
  var split_url = request.url.split('/')
  if (split_url[split_url.length - 1] == 'status') {
    response.statusCode = 200;
    response.write('');
    response.close();
    return;
  }
  var options  = optionsFromURL(request.url);
  var in_file  = options.in;
  var out_file = options.out;
  delete options.in;
  delete options.out;
  renderUrl(in_file, out_file, options, function() {
    return function(msg) {
      response.statusCode = 200;
      response.write(msg);
      response.close();
    }
  }());
})

console.log('listening on: ' + listen_on)
