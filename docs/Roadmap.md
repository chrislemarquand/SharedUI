# SharedUI Roadmap

## Future Notes

- Gallery detail row toggle:
  - Add a shared `showsGalleryDetailRow` setting exposed through each app's View menu.
  - Default behavior should be `true` in Ledger and `false` in Librarian.
  - Both apps should support toggling it at runtime.
  - Shared gallery layout should react by adding/removing supplementary detail height.
  - Ledger gallery items should show/hide filename detail row based on this setting.
  - Librarian can initially toggle layout space only (no detail text required yet).
