// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

let plugin = require('tailwindcss/plugin')

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex'
  ],
  theme: {
    extend: {
      fontFamily: {
        merriweather: ['Merriweather', 'sans-serif'],
        "crimson-pro": ['"Crimson Pro"', , '"Helvetica Neue"', 'Helvetica', 'Arial', 'sans-serif'],
        "source-serif-pro": ['"Source Serif Pro"', '"Helvetica Neue"', 'Helvetica', 'Arial', 'sans-serif'],
        "special-elite": ['"Special Elite"'],
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    plugin(({addVariant}) => addVariant('phx-click-loading', ['&.phx-click-loading', '.phx-click-loading &'])),
    plugin(({addVariant}) => addVariant('phx-submit-loading', ['&.phx-submit-loading', '.phx-submit-loading &'])),
    plugin(({addVariant}) => addVariant('phx-change-loading', ['&.phx-change-loading', '.phx-change-loading &']))
  ]
}
