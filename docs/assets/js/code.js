(function(win, site) {
  site.onReady(function() {
    var codeBlocks = document.querySelectorAll('div.highlighter-rouge, figure.highlight');

    var svgCopied =  '<svg viewBox="0 0 24 24" class="copy-icon"><use xlink:href="#svg-copied"></use></svg>';
    var svgCopy =  '<svg viewBox="0 0 24 24" class="copy-icon"><use xlink:href="#svg-copy"></use></svg>';

    codeBlocks.forEach(function(codeBlock) {
      var copyButton = document.createElement('button');
      var timeout = null;

      copyButton.type = 'button';
      copyButton.title = 'Copy';
      copyButton.ariaLabel = 'Copy code to clipboard';
      copyButton.innerHTML = svgCopy;
      codeBlock.append(copyButton);

      site.addEvent(copyButton, 'click', function() {
        if(win.navigator.clipboard && timeout === null) {
          var code = codeBlock.querySelector('pre:not(.lineno)').innerText;
          win.navigator.clipboard.writeText(code);

          copyButton.title = 'Copied';
          copyButton.innerHTML = svgCopied;

          var timeoutSetting = 4000;
          timeout = setTimeout(function() {
            copyButton.title = 'Copy';
            copyButton.innerHTML = svgCopy;
            timeout = null;
          }, timeoutSetting);
        }
      });
    });
  });
})(window, window.site);
