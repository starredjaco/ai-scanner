document.addEventListener("turbo:load", function() {
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  document.cookie = `browser_timezone=${timezone};path=/;max-age=31536000`;
});
