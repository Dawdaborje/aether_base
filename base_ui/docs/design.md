# UI components (`base_ui`)

Components only: `status_bar` and `form_bar`. A plugin that uses them lists `base_ui` under
`dependencies` and writes `<use component="base_ui.form_bar" …/>` at the top of a form view or beside
it on the page. The kernel moves the buttons and the state steps into the page's title bar, and
keeps Save as the form's own button. See `docs/plugin/pages.md` ("The form's top bar").
