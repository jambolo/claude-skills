// UI controller. Holds no application logic of its own — it forwards user
// intent through `api` and renders what the backend returns. The Rust core is
// the single source of truth for computation.

import { api } from './api';

const form = document.getElementById('greet-form') as HTMLFormElement;
const input = document.getElementById('greet-input') as HTMLInputElement;
const output = document.getElementById('greet-output') as HTMLParagraphElement;

form.addEventListener('submit', (event) => {
  event.preventDefault();
  api
    .greet(input.value)
    .then((greeting) => {
      output.textContent = greeting.message;
    })
    .catch((err: unknown) => {
      console.error(err);
      output.textContent = 'Could not reach the backend. Is the app running under Tauri?';
    });
});
