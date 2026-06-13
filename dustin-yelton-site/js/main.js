/* Mobile nav toggle + lightweight contact-form UX.
   No framework, no build step. */
(function () {
  // --- Mobile nav ---
  var toggle = document.querySelector(".nav-toggle");
  var links = document.querySelector(".nav-links");
  if (toggle && links) {
    toggle.addEventListener("click", function () {
      links.classList.toggle("open");
      var expanded = links.classList.contains("open");
      toggle.setAttribute("aria-expanded", expanded ? "true" : "false");
    });
    links.addEventListener("click", function (e) {
      if (e.target.tagName === "A") links.classList.remove("open");
    });
  }

  // --- Contact form ---
  // The form posts to a Formspree endpoint by default (no server needed).
  // Until a real endpoint is set, we intercept submit and show a friendly note
  // so the proof-of-concept never silently fails.
  var form = document.getElementById("estimate-form");
  if (form) {
    var action = form.getAttribute("action") || "";
    var isPlaceholder = action.indexOf("REPLACE_WITH_FORMSPREE_ID") !== -1 || action === "";
    if (isPlaceholder) {
      form.addEventListener("submit", function (e) {
        e.preventDefault();
        var status = document.getElementById("form-status");
        if (status) {
          status.style.display = "block";
          status.textContent =
            "Demo mode: connect a Formspree endpoint (or Squarespace form) to start receiving these messages by email.";
        }
      });
    }
  }

  // --- Footer year ---
  var y = document.getElementById("year");
  if (y) y.textContent = new Date().getFullYear();
})();
