// activeadmin_activejob: live poll for the jobs screens.
//
// While the page has a #jobs_live_poll element (rendered with the poll
// parameter), refreshes the jobs table, sidebar and tabs in place every
// data-interval milliseconds, pausing while the page is hidden, a job is
// selected or a field has focus. Swapping only those regions keeps Active
// Admin's batch action handlers working.
//
// Works with full page loads and with Turbo Drive: each page load restarts
// polling for the new page, and leaving the page stops it.
(function() {
  "use strict";

  var stopCurrent = function() {};

  function start(marker) {
    var interval = parseInt(marker.getAttribute("data-interval"), 10) || 2000;
    var busy = false;
    var stopped = false;
    var timer = null;

    function paused() {
      var active = document.activeElement;
      return busy || document.hidden ||
        document.querySelector(".paginated_collection input[type=checkbox]:checked") !== null ||
        (active !== null && /^(INPUT|SELECT|TEXTAREA)$/.test(active.tagName) && active.type !== "checkbox");
    }

    function replace(selector, doc) {
      var current = document.querySelector(selector);
      var fresh = doc.querySelector(selector);
      if (!current || !fresh) return false;
      current.replaceWith(document.importNode(fresh, true));
      return true;
    }

    function update(doc) {
      if (replace(".paginated_collection", doc)) {
        // Re-attach Active Admin's select-all handling to the new table.
        var table = window.jQuery && window.jQuery(".paginated_collection table.index_table");
        if (table && table.length && table.tableCheckboxToggler && document.querySelector("input.toggle_all")) {
          table.tableCheckboxToggler();
        }
      } else {
        replace("#main_content_wrapper", doc);
      }
      replace("#sidebar", doc);
      replace("#jobs_tabs", doc);
    }

    function schedule() {
      if (!stopped) timer = window.setTimeout(poll, interval);
    }

    function poll() {
      if (stopped || !document.body.contains(marker)) return stop();
      if (paused()) return schedule();
      busy = true;
      fetch(window.location.href, { headers: { Accept: "text/html" }, credentials: "same-origin" })
        .then(function(response) {
          // A redirect (e.g. to sign in) ends polling by following it.
          if (response.redirected) { window.location = response.url; throw new Error("redirected"); }
          if (!response.ok) throw new Error(response.status);
          return response.text();
        })
        .then(function(html) {
          if (!stopped) update(new DOMParser().parseFromString(html, "text/html"));
        })
        .catch(function() {})
        .then(function() { busy = false; schedule(); });
    }

    function stop() {
      stopped = true;
      window.clearTimeout(timer);
    }

    schedule();
    return stop;
  }

  function load() {
    stopCurrent();
    stopCurrent = function() {};
    var marker = document.getElementById("jobs_live_poll");
    if (marker) stopCurrent = start(marker);
  }

  function leave() {
    stopCurrent();
    stopCurrent = function() {};
  }

  // Turbo fires turbo:load on the first load too; load() is safe to repeat.
  document.addEventListener("DOMContentLoaded", load);
  document.addEventListener("turbo:load", load);
  document.addEventListener("turbo:before-visit", leave);
  document.addEventListener("turbo:before-cache", leave);
})();
