// Vanilla-JS context-menu behavior for UI::ContextMenuWithWebFallback.
// Pure DOM; no framework. Idempotent — safe to register multiple times
// (guarded by window.__apContextMenuInitialized).
//
// Behaviors:
//   * Trigger element opens menu on contextmenu (right-click) and long-press
//   * Menu positions itself near the trigger, flips when near viewport edge
//   * Arrow keys move focus between menuitems
//   * Home/End jump to first/last
//   * Escape closes; focus returns to trigger
//   * Click outside dismisses
//   * Enter/Space activates the focused item
//   * Disabled items are skipped by keyboard nav and not clickable
//
// Custom-event contract with Crystal-side hosts:
//   * Crystal emits <div class="ap-ctx-menu-host" data-ap-ctx-host>
//     wrapping a trigger element + a <ul class="ap-ctx-menu">.
//   * Action clicks dispatch CustomEvent("ap:ctx-menu:action",
//     { detail: { index, label } }) on the host.
//   * Any dismissal dispatches CustomEvent("ap:ctx-menu:dismiss",
//     { detail: { reason } }).
(function () {
  if (window.__apContextMenuInitialized) return;
  window.__apContextMenuInitialized = true;

  function itemsOf(menu) {
    return Array.prototype.filter.call(
      menu.querySelectorAll('.ap-ctx-menu__item'),
      function (el) { return el.getAttribute('aria-disabled') !== 'true'; }
    );
  }

  function position(menu, x, y) {
    menu.setAttribute('data-presented', 'true');
    var r = menu.getBoundingClientRect();
    var vw = window.innerWidth, vh = window.innerHeight;
    var left = (x + r.width > vw) ? Math.max(0, vw - r.width - 8) : x;
    var top  = (y + r.height > vh) ? Math.max(0, vh - r.height - 8) : y;
    menu.style.left = left + 'px';
    menu.style.top  = top  + 'px';
  }

  function open(host, x, y) {
    var menu = host.querySelector('.ap-ctx-menu');
    if (!menu) return;
    host.__previouslyFocused = document.activeElement;
    position(menu, x, y);
    var first = itemsOf(menu)[0];
    if (first) first.focus();
  }

  function close(host, reason) {
    var menu = host.querySelector('.ap-ctx-menu');
    if (!menu) return;
    menu.setAttribute('data-presented', 'false');
    host.dispatchEvent(new CustomEvent('ap:ctx-menu:dismiss',
      { detail: { reason: reason } }));
    if (host.__previouslyFocused &&
        typeof host.__previouslyFocused.focus === 'function') {
      host.__previouslyFocused.focus();
    }
  }

  function moveFocus(menu, dir) {
    var items = itemsOf(menu);
    if (items.length === 0) return;
    var i = items.indexOf(document.activeElement);
    var next;
    if (dir === 'first')     next = 0;
    else if (dir === 'last') next = items.length - 1;
    else if (dir === 'next') next = i < 0 ? 0 : (i + 1) % items.length;
    else if (dir === 'prev') next = i < 0 ? items.length - 1 : (i - 1 + items.length) % items.length;
    items[next].focus();
  }

  function attach(host) {
    if (host.__apBound) return;
    host.__apBound = true;

    var children = Array.prototype.slice.call(host.children);
    var trigger = null;
    for (var i = 0; i < children.length; i++) {
      if (!children[i].classList.contains('ap-ctx-menu')) {
        trigger = children[i]; break;
      }
    }
    if (!trigger) return;

    trigger.addEventListener('contextmenu', function (e) {
      e.preventDefault();
      open(host, e.clientX, e.clientY);
    });

    var pressTimer = null;
    trigger.addEventListener('touchstart', function (e) {
      if (e.touches.length !== 1) return;
      var t = e.touches[0];
      pressTimer = setTimeout(function () { open(host, t.clientX, t.clientY); }, 500);
    }, { passive: true });
    ['touchend', 'touchmove', 'touchcancel'].forEach(function (ev) {
      trigger.addEventListener(ev, function () { clearTimeout(pressTimer); }, { passive: true });
    });

    var menu = host.querySelector('.ap-ctx-menu');
    if (!menu) return;

    menu.addEventListener('click', function (e) {
      var item = e.target.closest('.ap-ctx-menu__item');
      if (!item || item.getAttribute('aria-disabled') === 'true') return;
      var index = parseInt(item.getAttribute('data-ap-ctx-action'), 10);
      host.dispatchEvent(new CustomEvent('ap:ctx-menu:action', {
        detail: { index: index, label: (item.textContent || '').trim() }
      }));
      close(host, 'action');
    });

    menu.addEventListener('keydown', function (e) {
      switch (e.key) {
        case 'Escape':    e.preventDefault(); close(host, 'escape'); break;
        case 'ArrowDown': e.preventDefault(); moveFocus(menu, 'next'); break;
        case 'ArrowUp':   e.preventDefault(); moveFocus(menu, 'prev'); break;
        case 'Home':      e.preventDefault(); moveFocus(menu, 'first'); break;
        case 'End':       e.preventDefault(); moveFocus(menu, 'last');  break;
        case 'Enter':
        case ' ':         e.preventDefault();
          if (document.activeElement) document.activeElement.click();
          break;
      }
    });

    document.addEventListener('click', function (e) {
      if (menu.getAttribute('data-presented') !== 'true') return;
      if (host.contains(e.target)) return;
      close(host, 'outside');
    });
  }

  function init() {
    var hosts = document.querySelectorAll('[data-ap-ctx-host]');
    for (var i = 0; i < hosts.length; i++) attach(hosts[i]);
  }

  if (document.readyState !== 'loading') init();
  else document.addEventListener('DOMContentLoaded', init);

  new MutationObserver(init).observe(document.documentElement,
    { childList: true, subtree: true });
})();
