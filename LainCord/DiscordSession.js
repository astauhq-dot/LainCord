// Runs at document start in the main frame of a temporary Discord web session.
(function (token) {
  'use strict';
  if (window.top !== window || window.location.origin !== 'https://discord.com') return;
  if (typeof token !== 'string' || token.length === 0) return;
  window.localStorage.setItem('token', JSON.stringify(token));
})
