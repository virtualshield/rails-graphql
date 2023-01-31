(function(site, doc) {
  // Shortcut for adding event listeners
  site.addEvent = function(el, type, handler) {
    if (el.attachEvent) {
      el.attachEvent('on'+type, handler);
    } else {
      el.addEventListener(type, handler);
    }
  };

  // Shortcut for removing event listeners
  site.removeEvent = function(el, type, handler) {
    if (el.detachEvent) {
      el.detachEvent('on'+type, handler);
    } else {
      el.removeEventListener(type, handler);
    }
  };

  // Shortcut for when js is ready
  site.onReady = function(ready) {
    if (doc.readyState != 'loading') {
      // in case the document is already rendered
      ready();
    } else if (doc.addEventListener) {
      // modern browsers
      doc.addEventListener('DOMContentLoaded', ready)
    } else {
      // IE <= 8
      doc.attachEvent('onreadystatechange', function() {
        (doc.readyState == 'complete') && ready();
      });
    }
  };
})(window.site = {}, document);
