// Presentation only: runs through the standalone builder's awaited --js hook.
// Keep the actual console, payloads and exploit in this document.
// Linux Loader theme: only display texts and the brand header differ from the original.
(function () {
  'use strict';
  var output = document.getElementById('console');
  if (!output || document.getElementById('loader')) return;

  function element(tag, id, parent, text) {
    var node = document.createElement(tag);
    node.id = id;
    if (text) node.textContent = text;
    parent.appendChild(node);
    return node;
  }

  var loader = element('main', 'loader', document.body);
  var wrapper = element('div', 'logWrapper', loader);
  wrapper.appendChild(output);
  var progress = element('div', 'progressContainer', loader);
  progress.setAttribute('role', 'progressbar');
  progress.setAttribute('aria-valuemin', '0');
  progress.setAttribute('aria-valuemax', '100');
  var bar = element('div', 'progressBar', progress);
  var label = element('div', 'progressLabel', progress);
  document.title = 'Linux Loader';

  // Brand header: small penguin + title
  var brand = element('div', 'brand', document.body);
  brand.innerHTML =
    '<svg viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">' +
    '<ellipse cx="50" cy="70" rx="34" ry="46" fill="#1f2937"/>' +
    '<ellipse cx="50" cy="78" rx="22" ry="33" fill="#f3f4f6"/>' +
    '<circle cx="40" cy="38" r="7" fill="#fff"/><circle cx="60" cy="38" r="7" fill="#fff"/>' +
    '<circle cx="41" cy="39" r="3" fill="#111"/><circle cx="59" cy="39" r="3" fill="#111"/>' +
    '<polygon points="41,48 59,48 50,60" fill="#f59e0b"/>' +
    '<ellipse cx="35" cy="112" rx="15" ry="6" fill="#f59e0b"/>' +
    '<ellipse cx="65" cy="112" rx="15" ry="6" fill="#f59e0b"/>' +
    '</svg><span>Linux <em>Loader</em></span>';

  var percent = 0;
  var finished = false;
  var sent = false;
  function update(next, message, state) {
    percent = Math.max(percent, next);
    bar.style.width = percent + '%';
    label.textContent = message;
    progress.setAttribute('aria-valuenow', String(percent));
    progress.setAttribute('aria-valuetext', message);
    progress.setAttribute('data-state', state || 'running');
  }
  update(0, 'Starting WebKit exploit...');

  function readLine(line) {
    var text = line.textContent || '';
    var error = /(?:^|\s)log-(?:error|minus)(?:\s|$)/.test(line.className);
    var summary = /queue finished: \d+\/\d+ completed, (\d+) failed/.exec(text);
    if (summary) {
      finished = true;
      if (Number(summary[1]) !== 0) update(percent, 'Autoload failed. See the log above.', 'error');
      else update(100, sent ? 'Autoload finished. Linux Loader should start now.' : 'Payloads finished.', 'done');
      return;
    }
    if (/queue stopped:/.test(text)) {
      finished = true;
      if (error) update(percent, 'Stopped. See the log above.', 'error');
      else if (/ELF loader is already accepting connections/.test(text))
        update(100, 'ELF loader already running. Nothing to do.', 'done');
      else update(percent, 'Stopped. See the log above.', 'stopped');
      return;
    }
    if (error) {
      update(percent, 'An error occurred. See the log above.', 'error');
      return;
    }
    if (finished) return;
    if (/Autoload: sent \d+ bytes/.test(text)) {
      sent = true;
      update(98, 'Finishing autoload...');
    } else if (/\[3\/3\].*autoload\.js/.test(text)) update(95, 'Loading autoload payload...');
    else if (/payloads loaded|elfldr.*listening/i.test(text)) update(90, 'ELF loader ready...');
    else if (/privileges ready/i.test(text)) update(80, 'Privileges ready...');
    else if (/read and write ready/i.test(text)) update(65, 'Kernel read/write ready...');
    else if (/Starting kernel exploit|\[2\/3\]/i.test(text)) update(40, 'Starting kernel exploit...');
    else if (/\[1\/3\].*elfldr-check\.js/.test(text)) update(35, 'Checking ELF loader...');
    else if (/Worker chain: ready/i.test(text)) update(30, 'WebKit ready...');
    else if (/ARW ready/i.test(text)) update(20, 'Preparing WebKit...');
    else if (/Starting WebKit exploit/i.test(text)) update(10, 'Starting WebKit exploit...');
    else {
      var stage = /\bSTAGE\s*([0-5])\b/i.exec(text);
      if (stage) update(40 + Number(stage[1]) * 10, 'Running kernel exploit...');
    }
  }

  // Observe the native log instead of replacing writeLog or the module APIs.
  // Process only changed lines, including in-place stage updates.
  var observer = new MutationObserver(function (records) {
    var changed = [];
    function remember(node) {
      if (node.nodeType !== 1) node = node.parentNode;
      while (node && node.parentNode !== output) node = node.parentNode;
      if (node && changed.indexOf(node) < 0) changed.push(node);
    }
    records.forEach(function (record) {
      if (record.target === output) {
        for (var i = 0; i < record.addedNodes.length; i++) remember(record.addedNodes[i]);
      } else remember(record.target);
    });
    changed.forEach(readLine);
    while (output.children.length > 80) output.removeChild(output.firstElementChild);
    wrapper.scrollTop = wrapper.scrollHeight;
  });
  observer.observe(output, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ['class'] });
}());
